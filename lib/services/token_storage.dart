import 'package:shared_preferences/shared_preferences.dart';

/// Guarda o token JWT (devolvido pela API em nuvem no login) e os dados
/// básicos da sessão, para o usuário continuar logado entre aberturas do
/// app mesmo se a nuvem estiver indisponível no momento.
class TokenStorage {
  static const _chaveToken = 'jwt_token';
  static const _chaveUsuarioId = 'usuario_id';
  static const _chaveUsuarioNome = 'usuario_nome';
  static const _chaveUsuarioLogin = 'usuario_login';
  static const _chaveUsuarioPerfil = 'usuario_perfil';

  Future<void> salvarSessao({
    required String? token,
    required int usuarioId,
    required String nome,
    required String login,
    required String perfil,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_chaveToken, token);
    } else {
      await prefs.remove(_chaveToken);
    }
    await prefs.setInt(_chaveUsuarioId, usuarioId);
    await prefs.setString(_chaveUsuarioNome, nome);
    await prefs.setString(_chaveUsuarioLogin, login);
    await prefs.setString(_chaveUsuarioPerfil, perfil);
  }

  Future<String?> lerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chaveToken);
  }

  Future<Map<String, dynamic>?> lerSessaoSalva() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_chaveUsuarioId);
    if (id == null) return null;
    return {
      'id': id,
      'nome': prefs.getString(_chaveUsuarioNome) ?? '',
      'login': prefs.getString(_chaveUsuarioLogin) ?? '',
      'perfil': prefs.getString(_chaveUsuarioPerfil) ?? 'funcionario',
      'token': prefs.getString(_chaveToken),
    };
  }

  Future<void> limpar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveToken);
    await prefs.remove(_chaveUsuarioId);
    await prefs.remove(_chaveUsuarioNome);
    await prefs.remove(_chaveUsuarioLogin);
    await prefs.remove(_chaveUsuarioPerfil);
  }
}
