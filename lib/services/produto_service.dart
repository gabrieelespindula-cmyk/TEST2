import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/produto.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'sync_queue.dart';
import 'data_notifier.dart';

/// Acesso a produtos com estratégia offline-first:
/// - Leituras: tenta a API; se der certo, atualiza o cache local (SQLite)
///   e retorna os dados da nuvem; se falhar (sem internet/API fora do ar),
///   retorna o que estiver no cache local.
/// - Escritas: tenta a API; se não houver conexão, grava localmente e
///   enfileira a operação em `fila_sincronizacao` para reenviar depois
///   (ver SyncService).
class ProdutoService {
  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncQueue _fila = SyncQueue();

  // RF07, RF11 - Consulta e busca por nome/categoria
  Future<List<Produto>> listar({String? busca, String? categoria}) async {
    if (await _connectivity.apiEstaDisponivel()) {
      try {
        final query = <String>[];
        if (busca != null && busca.trim().isNotEmpty) query.add('busca=${Uri.encodeQueryComponent(busca.trim())}');
        if (categoria != null && categoria.trim().isNotEmpty) {
          query.add('categoria=${Uri.encodeQueryComponent(categoria)}');
        }
        final path = '/api/produto${query.isNotEmpty ? '?${query.join('&')}' : ''}';
        final resposta = await _api.get(path) as List<dynamic>;
        final produtos = resposta.map((j) => Produto.fromApiJson(j as Map<String, dynamic>)).toList();
        await _atualizarCacheLocal(produtos);
        return produtos;
      } on ApiIndisponivelException {
        // segue para o fallback local
      }
    }
    return _listarLocal(busca: busca, categoria: categoria);
  }

  Future<List<Produto>> _listarLocal({String? busca, String? categoria}) async {
    final db = await DatabaseHelper.instance.database;
    final where = <String>[];
    final args = <Object?>[];

    if (busca != null && busca.trim().isNotEmpty) {
      where.add('nome LIKE ?');
      args.add('%${busca.trim()}%');
    }
    if (categoria != null && categoria.trim().isNotEmpty) {
      where.add('categoria = ?');
      args.add(categoria);
    }

    final result = await db.query(
      'produtos',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'nome ASC',
    );
    return result.map((m) => Produto.fromMap(m)).toList();
  }

  /// Faz um "upsert" simples dos produtos vindos da nuvem no cache local,
  /// para que o app continue funcionando quando a conexão cair em seguida.
  Future<void> _atualizarCacheLocal(List<Produto> produtos) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (final p in produtos) {
      batch.insert('produtos', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<String>> listarCategorias() async {
    if (await _connectivity.apiEstaDisponivel()) {
      try {
        final resposta = await _api.get('/api/produto/categorias') as List<dynamic>;
        return resposta.map((c) => c.toString()).toList();
      } on ApiIndisponivelException {
        // fallback local
      }
    }
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      "SELECT DISTINCT categoria FROM produtos WHERE categoria IS NOT NULL AND categoria != '' ORDER BY categoria",
    );
    return result.map((m) => m['categoria'] as String).toList();
  }

  Future<Produto?> buscarPorId(int id) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('produtos', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Produto.fromMap(result.first);
  }

  // RF04 - Cadastro de produtos
  Future<int> criar(Produto produto) async {
    final db = await DatabaseHelper.instance.database;

    if (await _connectivity.apiEstaDisponivel()) {
      try {
        final resposta = await _api.post('/api/produto', produto.toApiJson());
        final criado = Produto.fromApiJson(resposta as Map<String, dynamic>);
        await db.insert('produtos', criado.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        DataNotifier.bump();
        return criado.id!;
      } on ApiIndisponivelException {
        // segue para criação offline
      }
    }

    final idLocal = await db.insert('produtos', produto.toMap()..remove('id'));
    await _fila.adicionar(
      tipo: 'produto',
      operacao: 'criar',
      payload: produto.toApiJson(),
      referenciaLocalId: idLocal,
    );
    DataNotifier.bump();
    return idLocal;
  }

  // RF05 - Atualização de produtos
  Future<void> atualizar(Produto produto) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('produtos', produto.toMap(), where: 'id = ?', whereArgs: [produto.id]);
    DataNotifier.bump();

    if (await _connectivity.apiEstaDisponivel()) {
      try {
        await _api.put('/api/produto/${produto.id}', produto.toApiJson());
        return;
      } on ApiIndisponivelException {
        // segue para a fila
      }
    }
    await _fila.adicionar(
      tipo: 'produto',
      operacao: 'atualizar',
      payload: produto.toApiJson(),
      referenciaLocalId: produto.id,
    );
  }

  // RF06 - Atualização de estoque (entrada/saída manual pelo gerente)
  Future<Produto> atualizarEstoque(int produtoId, int quantidadeAjuste) async {
    final db = await DatabaseHelper.instance.database;
    final produto = await buscarPorId(produtoId);
    if (produto == null) {
      throw Exception('Produto não encontrado.');
    }
    final novaQuantidade = produto.quantidadeEstoque + quantidadeAjuste;
    if (novaQuantidade < 0) {
      throw Exception('Estoque não pode ficar negativo.');
    }
    final atualizado = produto.copyWith(quantidadeEstoque: novaQuantidade);
    await db.update('produtos', atualizado.toMap(), where: 'id = ?', whereArgs: [produtoId]);
    DataNotifier.bump();

    if (await _connectivity.apiEstaDisponivel()) {
      try {
        await _api.post('/api/produto/$produtoId/estoque', {'ajuste': quantidadeAjuste});
        return atualizado;
      } on ApiIndisponivelException {
        // segue para a fila
      }
    }
    await _fila.adicionar(
      tipo: 'estoque',
      operacao: 'atualizar',
      payload: {'ajuste': quantidadeAjuste},
      referenciaLocalId: produtoId,
    );
    return atualizado;
  }

  // RF12 - Produtos com estoque baixo (<20)
  Future<List<Produto>> listarEstoqueBaixo() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'produtos',
      where: 'quantidadeEstoque < ?',
      whereArgs: [20],
      orderBy: 'quantidadeEstoque ASC',
    );
    return result.map((m) => Produto.fromMap(m)).toList();
  }

  Future<void> excluir(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('produtos', where: 'id = ?', whereArgs: [id]);
  }
}
