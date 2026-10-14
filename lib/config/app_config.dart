import 'package:shared_preferences/shared_preferences.dart';

/// Configuração de conexão com a nuvem. A URL da API fica salva no
/// dispositivo (SharedPreferences) para que o aluno possa apontar o app
/// para o servidor correto na hora da apresentação (localhost da própria
/// máquina durante o desenvolvimento, ou a URL pública depois do deploy),
/// sem precisar recompilar o app.
class AppConfig {
  AppConfig._internal();
  static final AppConfig instance = AppConfig._internal();

  static const _chaveApiBaseUrl = 'api_base_url';
  static const _chaveSyncAtivo = 'sync_ativo';

  // Ajuste este valor para a URL da sua API publicada na nuvem
  // (ex.: Railway, Azure, Render) ou para o IP da sua máquina na rede local
  // durante o desenvolvimento (ex.: http://192.168.0.10:5000).
  static const String urlPadrao = 'http://10.0.2.2:5000';

  String? _apiBaseUrl;
  bool _syncAtivo = true;

  String get apiBaseUrl => _apiBaseUrl ?? urlPadrao;
  bool get syncAtivo => _syncAtivo;

  Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBaseUrl = prefs.getString(_chaveApiBaseUrl);
    _syncAtivo = prefs.getBool(_chaveSyncAtivo) ?? true;
  }

  Future<void> salvarApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final limpo = url.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString(_chaveApiBaseUrl, limpo);
    _apiBaseUrl = limpo;
  }

  Future<void> definirSyncAtivo(bool ativo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chaveSyncAtivo, ativo);
    _syncAtivo = ativo;
  }
}
