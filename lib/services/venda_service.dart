import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/produto.dart';
import '../models/usuario.dart';
import '../models/venda.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'sync_queue.dart';
import 'data_notifier.dart';

class ItemCarrinho {
  final Produto produto;
  int quantidade;

  ItemCarrinho({required this.produto, this.quantidade = 1});

  double get subtotal => produto.preco * quantidade;
}

/// Acesso a vendas com estratégia offline-first (ver comentário em
/// ProdutoService para a ideia geral). Vendas são o caso mais sensível
/// porque envolvem baixa de estoque, então cuidamos para que o
/// comportamento seja idêntico online e offline.
class VendaService {
  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncQueue _fila = SyncQueue();

  // RF14 - Histórico de vendas
  Future<List<Venda>> listar() async {
    if (await _connectivity.apiEstaDisponivel()) {
      try {
        final resposta = await _api.get('/api/venda') as List<dynamic>;
        final vendas = resposta.map((j) => Venda.fromApiJson(j as Map<String, dynamic>)).toList();
        await _atualizarCacheLocal(vendas);
        return vendas;
      } on ApiIndisponivelException {
        // fallback local abaixo
      }
    }
    return _listarLocal();
  }

  Future<List<Venda>> _listarLocal() async {
    final db = await DatabaseHelper.instance.database;
    final vendasRaw = await db.query('vendas', orderBy: 'data DESC');
    final vendas = <Venda>[];
    for (final v in vendasRaw) {
      vendas.add(await _hidratarVenda(db, v));
    }
    return vendas;
  }

  Future<void> _atualizarCacheLocal(List<Venda> vendas) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final v in vendas) {
        await txn.insert('vendas', v.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        for (final item in v.itens) {
          await txn.insert(
            'itens_venda',
            {
              'id': item.id,
              'vendaId': v.id,
              'produtoId': item.produtoId,
              'quantidade': item.quantidade,
              'precoUnitario': item.precoUnitario,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<Venda?> buscarPorId(int id) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('vendas', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return _hidratarVenda(db, result.first);
  }

  Future<Venda> _hidratarVenda(Database db, Map<String, dynamic> vendaMap) async {
    final usuarioRes = await db.query('usuarios', where: 'id = ?', whereArgs: [vendaMap['usuarioId']]);
    final usuario = usuarioRes.isNotEmpty ? Usuario.fromMap(usuarioRes.first) : null;

    final itensRaw = await db.query('itens_venda', where: 'vendaId = ?', whereArgs: [vendaMap['id']]);
    final itens = <ItemVenda>[];
    for (final i in itensRaw) {
      final produtoRes = await db.query('produtos', where: 'id = ?', whereArgs: [i['produtoId']]);
      final produto = produtoRes.isNotEmpty ? Produto.fromMap(produtoRes.first) : null;
      itens.add(ItemVenda.fromMap(i, produto: produto));
    }

    return Venda.fromMap(vendaMap, usuario: usuario, itens: itens);
  }

  // RF08, RF09 - Registrar venda + baixa automática de estoque
  Future<Venda> registrar({
    required int usuarioId,
    required List<ItemCarrinho> carrinho,
  }) async {
    if (carrinho.isEmpty) {
      throw Exception('Adicione pelo menos um produto à venda.');
    }

    if (await _connectivity.apiEstaDisponivel()) {
      try {
        return await _registrarRemoto(usuarioId: usuarioId, carrinho: carrinho);
      } on ApiIndisponivelException {
        // segue para registro offline
      }
      // ApiException (ex.: estoque insuficiente na nuvem) propaga normalmente
    }

    return _registrarLocal(usuarioId: usuarioId, carrinho: carrinho);
  }

  Future<Venda> _registrarRemoto({required int usuarioId, required List<ItemCarrinho> carrinho}) async {
    final payloadItens = carrinho.map((i) => {'produtoId': i.produto.id, 'quantidade': i.quantidade}).toList();
    final resposta = await _api.post('/api/venda', {'itens': payloadItens});
    final venda = Venda.fromApiJson(resposta as Map<String, dynamic>);

    // Espelha no banco local: venda, itens e novo estoque dos produtos.
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await txn.insert('vendas', venda.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      for (final item in venda.itens) {
        await txn.insert(
          'itens_venda',
          {
            'vendaId': venda.id,
            'produtoId': item.produtoId,
            'quantidade': item.quantidade,
            'precoUnitario': item.precoUnitario,
          },
        );
        await txn.rawUpdate(
          'UPDATE produtos SET quantidadeEstoque = quantidadeEstoque - ? WHERE id = ?',
          [item.quantidade, item.produtoId],
        );
      }
    });

    DataNotifier.bump();
    return venda;
  }

  Future<Venda> _registrarLocal({required int usuarioId, required List<ItemCarrinho> carrinho}) async {
    final db = await DatabaseHelper.instance.database;
    late int vendaId;
    double total = 0;

    await db.transaction((txn) async {
      for (final item in carrinho) {
        final produtoRes = await txn.query('produtos', where: 'id = ?', whereArgs: [item.produto.id]);
        if (produtoRes.isEmpty) {
          throw Exception("Produto '${item.produto.nome}' não encontrado.");
        }
        final estoqueAtual = produtoRes.first['quantidadeEstoque'] as int;
        if (estoqueAtual < item.quantidade) {
          throw Exception("Estoque insuficiente para '${item.produto.nome}'. Disponível: $estoqueAtual.");
        }
      }

      total = carrinho.fold(0.0, (sum, i) => sum + i.subtotal);

      vendaId = await txn.insert('vendas', {
        'data': DateTime.now().toIso8601String(),
        'valorTotal': total,
        'status': 'Ativa',
        'usuarioId': usuarioId,
      });

      for (final item in carrinho) {
        await txn.insert('itens_venda', {
          'vendaId': vendaId,
          'produtoId': item.produto.id,
          'quantidade': item.quantidade,
          'precoUnitario': item.produto.preco,
        });

        await txn.rawUpdate(
          'UPDATE produtos SET quantidadeEstoque = quantidadeEstoque - ? WHERE id = ?',
          [item.quantidade, item.produto.id],
        );
      }
    });

    // Enfileira a venda inteira para ser recriada na nuvem quando a
    // conexão voltar (ver SyncService).
    await _fila.adicionar(
      tipo: 'venda',
      operacao: 'criar',
      payload: {
        'itens': carrinho.map((i) => {'produtoId': i.produto.id, 'quantidade': i.quantidade}).toList(),
      },
      referenciaLocalId: vendaId,
    );

    DataNotifier.bump();
    return (await buscarPorId(vendaId))!;
  }

  // RF13 - Cancelamento de venda + devolução ao estoque
  Future<void> cancelar(int vendaId) async {
    if (await _connectivity.apiEstaDisponivel()) {
      try {
        await _api.post('/api/venda/$vendaId/cancelar', {});
        await _cancelarLocal(vendaId, enfileirar: false);
        DataNotifier.bump();
        return;
      } on ApiIndisponivelException {
        // segue para cancelamento offline
      }
    }
    await _cancelarLocal(vendaId, enfileirar: true);
    DataNotifier.bump();
  }

  Future<void> _cancelarLocal(int vendaId, {required bool enfileirar}) async {
    final db = await DatabaseHelper.instance.database;

    await db.transaction((txn) async {
      final vendaRes = await txn.query('vendas', where: 'id = ?', whereArgs: [vendaId]);
      if (vendaRes.isEmpty) {
        throw Exception('Venda não encontrada.');
      }
      if (vendaRes.first['status'] == 'Cancelada') {
        if (!enfileirar) return; // já cancelada localmente, nada a fazer
        throw Exception('Esta venda já está cancelada.');
      }

      final itens = await txn.query('itens_venda', where: 'vendaId = ?', whereArgs: [vendaId]);
      for (final item in itens) {
        await txn.rawUpdate(
          'UPDATE produtos SET quantidadeEstoque = quantidadeEstoque + ? WHERE id = ?',
          [item['quantidade'], item['produtoId']],
        );
      }

      await txn.update('vendas', {'status': 'Cancelada'}, where: 'id = ?', whereArgs: [vendaId]);
    });

    if (!enfileirar) return;

    // Se a própria criação da venda ainda está pendente de sincronização
    // (ou seja, ela nunca existiu na nuvem), basta remover aquela
    // operação da fila — não há nada para "cancelar" no servidor.
    final pendentes = await _fila.listarPendentes();
    final criacaoPendente = pendentes
        .where((p) => p.tipo == 'venda' && p.operacao == 'criar' && p.referenciaLocalId == vendaId)
        .toList();

    if (criacaoPendente.isNotEmpty) {
      await _fila.remover(criacaoPendente.first.id);
      return;
    }

    await _fila.adicionar(
      tipo: 'venda',
      operacao: 'cancelar',
      payload: {},
      referenciaLocalId: vendaId,
    );
  }
}
