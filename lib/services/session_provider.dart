import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/usuario.dart';
import '../utils/password_utils.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'token_storage.dart';

/// Gerencia o estado de sessão do usuário logado.
///
/// Estratégia offline-first:
/// 1. Tenta autenticar contra a API em nuvem (POST /api/auth/login).
/// 2. Se a nuvem responder OK: salva o token JWT e espelha o usuário no
///    SQLite local (para permitir login offline depois).
/// 3. Se não houver internet / API fora do ar: cai para verificação local
///    (SQLite), usando a última senha sincronizada.
class SessionProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final TokenStorage _tokenStorage = TokenStorage();
  final ConnectivityService _connectivity = ConnectivityService();

  Usuario? _usuarioLogado;
  bool _modoOffline = false;

  Usuario? get usuario => _usuarioLogado;
  bool get isLogado => _usuarioLogado != null;
  bool get isGerente => _usuarioLogado?.isGerente ?? false;
  bool get modoOffline => _modoOffline;

  /// Tenta restaurar uma sessão salva (ex.: ao reabrir o app).
  Future<bool> restaurarSessao() async {
    final sessao = await _tokenStorage.lerSessaoSalva();
    if (sessao == null) return false;

    _usuarioLogado = Usuario(
      id: sessao['id'] as int,
      nome: sessao['nome'] as String,
      login: sessao['login'] as String,
      senhaHash: '',
      perfil: sessao['perfil'] as String,
    );
    _modoOffline = sessao['token'] == null;
    notifyListeners();
    return true;
  }

  Future<String?> login(String login, String senha) async {
    final online = await _connectivity.apiEstaDisponivel();

    if (online) {
      try {
        return await _loginRemoto(login, senha);
      } on ApiException catch (e) {
        // Erro de negócio da API (ex.: 401 login/senha inválidos) — não
        // faz sentido cair para o modo local nesse caso.
        return e.mensagem;
      } on ApiIndisponivelException {
        // A rede caiu bem na hora da requisição: tenta localmente.
        return _loginLocal(login, senha);
      }
    }

    return _loginLocal(login, senha);
  }

  Future<String?> _loginRemoto(String login, String senha) async {
    final resposta = await _api.post(
      '/api/auth/login',
      {'login': login, 'senha': senha},
      comAuth: false,
    );

    final usuarioJson = resposta['usuario'] as Map<String, dynamic>;
    final token = resposta['token'] as String?;
    final usuario = Usuario.fromApiJson(usuarioJson);

    await _tokenStorage.salvarSessao(
      token: token,
      usuarioId: usuario.id!,
      nome: usuario.nome,
      login: usuario.login,
      perfil: usuario.perfil,
    );

    // Espelha/atualiza o usuário no SQLite local, para permitir login
    // offline mais tarde (a senha local continua sendo o hash SHA-256,
    // já que não recebemos a senha em texto puro da API).
    await _espelharUsuarioLocal(usuario, senha);

    _usuarioLogado = usuario;
    _modoOffline = false;
    notifyListeners();
    return null;
  }

  Future<void> _espelharUsuarioLocal(Usuario usuario, String senha) async {
    final db = await DatabaseHelper.instance.database;
    final existente = await db.query('usuarios', where: 'login = ?', whereArgs: [usuario.login]);
    final senhaHash = PasswordUtils.hash(senha);

    if (existente.isEmpty) {
      await db.insert('usuarios', {
        'nome': usuario.nome,
        'login': usuario.login,
        'senha': senhaHash,
        'perfil': usuario.perfil,
      });
    } else {
      await db.update(
        'usuarios',
        {'nome': usuario.nome, 'senha': senhaHash, 'perfil': usuario.perfil},
        where: 'login = ?',
        whereArgs: [usuario.login],
      );
    }
  }

  Future<String?> _loginLocal(String login, String senha) async {
    final db = await DatabaseHelper.instance.database;
    final resultado = await db.query('usuarios', where: 'login = ?', whereArgs: [login], limit: 1);

    if (resultado.isEmpty) {
      return 'Login ou senha inválidos (sem conexão com a nuvem no momento).';
    }

    final usuario = Usuario.fromMap(resultado.first);
    if (!PasswordUtils.verify(senha, usuario.senhaHash)) {
      return 'Login ou senha inválidos (sem conexão com a nuvem no momento).';
    }

    await _tokenStorage.salvarSessao(
      token: null,
      usuarioId: usuario.id!,
      nome: usuario.nome,
      login: usuario.login,
      perfil: usuario.perfil,
    );

    _usuarioLogado = usuario;
    _modoOffline = true;
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    await _tokenStorage.limpar();
    _usuarioLogado = null;
    notifyListeners();
  }

  /// Chamado pelo SyncService quando a conexão com a nuvem é confirmada,
  /// para tirar o selo de "modo offline" da interface.
  void marcarOnline() {
    if (_modoOffline) {
      _modoOffline = false;
      notifyListeners();
    }
  }
}
