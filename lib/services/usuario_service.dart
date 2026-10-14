import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/usuario.dart';
import '../utils/password_utils.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'sync_queue.dart';

class UsuarioService {
  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();
  final SyncQueue _fila = SyncQueue();

  Future<List<Usuario>> listar() async {
    if (await _connectivity.apiEstaDisponivel()) {
      try {
        final resposta = await _api.get('/api/usuario') as List<dynamic>;
        final usuarios = resposta.map((j) => Usuario.fromApiJson(j as Map<String, dynamic>)).toList();
        final db = await DatabaseHelper.instance.database;
        final batch = db.batch();
        for (final u in usuarios) {
          // Preserva a senha local já salva (a API não devolve hash de senha)
          batch.rawUpdate(
            'UPDATE usuarios SET nome = ?, perfil = ? WHERE login = ?',
            [u.nome, u.perfil, u.login],
          );
        }
        await batch.commit(noResult: true);
        return usuarios;
      } on ApiIndisponivelException {
        // fallback local
      }
    }
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('usuarios', orderBy: 'nome ASC');
    return result.map((m) => Usuario.fromMap(m)).toList();
  }

  // RF03 - Cadastro de usuários
  Future<int> criar({
    required String nome,
    required String login,
    required String senha,
    required String perfil,
  }) async {
    final db = await DatabaseHelper.instance.database;

    final existente = await db.query('usuarios', where: 'login = ?', whereArgs: [login]);
    if (existente.isNotEmpty) {
      throw Exception('Este login já está em uso.');
    }

    if (await _connectivity.apiEstaDisponivel()) {
      try {
        final resposta = await _api.post('/api/usuario', {
          'nome': nome,
          'login': login,
          'senha': senha,
          'perfil': perfil,
        });
        final criado = Usuario.fromApiJson(resposta as Map<String, dynamic>);
        return db.insert('usuarios', {
          'id': criado.id,
          'nome': criado.nome,
          'login': criado.login,
          'senha': PasswordUtils.hash(senha),
          'perfil': criado.perfil,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } on ApiIndisponivelException {
        // segue para criação offline
      }
    }

    final idLocal = await db.insert('usuarios', {
      'nome': nome,
      'login': login,
      'senha': PasswordUtils.hash(senha),
      'perfil': perfil,
    });

    await _fila.adicionar(
      tipo: 'usuario',
      operacao: 'criar',
      payload: {'nome': nome, 'login': login, 'senha': senha, 'perfil': perfil},
      referenciaLocalId: idLocal,
    );

    return idLocal;
  }

  Future<void> excluir(int id, {required int usuarioLogadoId}) async {
    if (id == usuarioLogadoId) {
      throw Exception('Você não pode excluir sua própria conta.');
    }
    final db = await DatabaseHelper.instance.database;
    await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);

    if (await _connectivity.apiEstaDisponivel()) {
      try {
        await _api.delete('/api/usuario/$id');
        return;
      } on ApiIndisponivelException {
        // segue para a fila
      }
    }
    await _fila.adicionar(tipo: 'usuario', operacao: 'excluir', payload: {}, referenciaLocalId: id);
  }
}
