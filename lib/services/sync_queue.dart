import 'dart:convert';
import '../db/database_helper.dart';

class ItemFilaSincronizacao {
  final int id;
  final String tipo;
  final String operacao;
  final Map<String, dynamic> payload;
  final int? referenciaLocalId;
  final int tentativas;

  ItemFilaSincronizacao({
    required this.id,
    required this.tipo,
    required this.operacao,
    required this.payload,
    required this.referenciaLocalId,
    required this.tentativas,
  });

  factory ItemFilaSincronizacao.fromMap(Map<String, dynamic> map) {
    return ItemFilaSincronizacao(
      id: map['id'] as int,
      tipo: map['tipo'] as String,
      operacao: map['operacao'] as String,
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      referenciaLocalId: map['referenciaLocalId'] as int?,
      tentativas: map['tentativas'] as int,
    );
  }
}

/// Acesso à tabela `fila_sincronizacao`: guarda operações feitas enquanto
/// o app está offline, para reenviar à API quando a conexão voltar.
class SyncQueue {
  Future<void> adicionar({
    required String tipo,
    required String operacao,
    required Map<String, dynamic> payload,
    int? referenciaLocalId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('fila_sincronizacao', {
      'tipo': tipo,
      'operacao': operacao,
      'payload': jsonEncode(payload),
      'referenciaLocalId': referenciaLocalId,
      'criadoEm': DateTime.now().toIso8601String(),
      'tentativas': 0,
    });
  }

  Future<List<ItemFilaSincronizacao>> listarPendentes() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('fila_sincronizacao', orderBy: 'id ASC');
    return result.map((m) => ItemFilaSincronizacao.fromMap(m)).toList();
  }

  Future<int> contarPendentes() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as total FROM fila_sincronizacao');
    return (result.first['total'] as int?) ?? 0;
  }

  Future<void> remover(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('fila_sincronizacao', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> registrarFalha(int id, String erro) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      'UPDATE fila_sincronizacao SET tentativas = tentativas + 1, ultimoErro = ? WHERE id = ?',
      [erro, id],
    );
  }
}
