import '../db/database_helper.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'sync_queue.dart';
import 'data_notifier.dart';

class ResultadoSincronizacao {
  final int sincronizados;
  final int falharam;
  final List<String> erros;
  ResultadoSincronizacao({required this.sincronizados, required this.falharam, required this.erros});
}

/// Reenvia para a API tudo o que foi feito offline (fila_sincronizacao),
/// na ordem em que foi criado. É acionado:
/// - manualmente (botão "Sincronizar agora" na tela de Perfil);
/// - automaticamente quando a conectividade volta (ver main.dart).
class SyncService {
  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncQueue _fila = SyncQueue();

  static const _maxTentativas = 4;

  Future<ResultadoSincronizacao> sincronizar() async {
    if (!await _connectivity.apiEstaDisponivel()) {
      return ResultadoSincronizacao(sincronizados: 0, falharam: 0, erros: []);
    }

    final pendentes = await _fila.listarPendentes();
    int ok = 0;
    int falhas = 0;
    final erros = <String>[];

    for (final item in pendentes) {
      try {
        await _processar(item);
        await _fila.remover(item.id);
        ok++;
      } on ApiIndisponivelException {
        // A conexão caiu no meio da sincronização: para por aqui e tenta
        // novamente na próxima vez (os itens já processados continuam ok).
        break;
      } on ApiException catch (e) {
        falhas++;
        erros.add('${item.tipo} #${item.referenciaLocalId}: ${e.mensagem}');
        await _fila.registrarFalha(item.id, e.mensagem);
        if (item.tentativas + 1 >= _maxTentativas) {
          // Desiste depois de várias tentativas, para não travar a fila
          // para sempre por causa de um item problemático.
          await _fila.remover(item.id);
        }
      }
    }

    if (ok > 0) DataNotifier.bump();
    return ResultadoSincronizacao(sincronizados: ok, falharam: falhas, erros: erros);
  }

  Future<void> _processar(ItemFilaSincronizacao item) async {
    switch (item.tipo) {
      case 'produto':
        await _processarProduto(item);
        break;
      case 'estoque':
        await _api.post('/api/produto/${item.referenciaLocalId}/estoque', item.payload);
        break;
      case 'venda':
        await _processarVenda(item);
        break;
      case 'usuario':
        await _processarUsuario(item);
        break;
    }
  }

  Future<void> _processarProduto(ItemFilaSincronizacao item) async {
    if (item.operacao == 'criar') {
      final resposta = await _api.post('/api/produto', item.payload) as Map<String, dynamic>;
      final idRemoto = resposta['id'] as int;
      if (item.referenciaLocalId != null && idRemoto != item.referenciaLocalId) {
        await _remapearId('produtos', idRemoto, item.referenciaLocalId!, referenciasEm: {
          'itens_venda': 'produtoId',
        });
      }
    } else if (item.operacao == 'atualizar') {
      await _api.put('/api/produto/${item.referenciaLocalId}', item.payload);
    }
  }

  Future<void> _processarVenda(ItemFilaSincronizacao item) async {
    if (item.operacao == 'criar') {
      final resposta = await _api.post('/api/venda', item.payload) as Map<String, dynamic>;
      final idRemoto = resposta['id'] as int;
      if (item.referenciaLocalId != null && idRemoto != item.referenciaLocalId) {
        await _remapearId('vendas', idRemoto, item.referenciaLocalId!, referenciasEm: {
          'itens_venda': 'vendaId',
        });
      }
    } else if (item.operacao == 'cancelar') {
      await _api.post('/api/venda/${item.referenciaLocalId}/cancelar', {});
    }
  }

  Future<void> _processarUsuario(ItemFilaSincronizacao item) async {
    if (item.operacao == 'criar') {
      await _api.post('/api/usuario', item.payload);
    } else if (item.operacao == 'excluir') {
      await _api.delete('/api/usuario/${item.referenciaLocalId}');
    }
  }

  /// Uma linha criada offline recebe um id provisório (gerado pelo SQLite
  /// local). Quando a nuvem confirma a criação, ela devolve o id "real" —
  /// aqui trocamos o id local pelo id da nuvem, e atualizamos qualquer
  /// tabela que referenciava o id provisório (ex.: itens_venda.produtoId).
  Future<void> _remapearId(
    String tabela,
    int idNovo,
    int idAntigo, {
    required Map<String, String> referenciasEm,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.update(tabela, {'id': idNovo}, where: 'id = ?', whereArgs: [idAntigo]);
      for (final entrada in referenciasEm.entries) {
        await txn.update(
          entrada.key,
          {entrada.value: idNovo},
          where: '${entrada.value} = ?',
          whereArgs: [idAntigo],
        );
      }
    });
  }
}
