import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/app_config.dart';

/// Verifica se o app tem uma conexão "de verdade" com a API em nuvem.
///
/// Importante: `connectivity_plus` só diz se o celular está conectado a
/// uma rede Wi-Fi/dados — não garante que exista internet real, nem que a
/// API esteja no ar. Por isso, além de checar a rede, fazemos uma
/// tentativa rápida de conexão TCP com o host da API configurada.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> temRedeDisponivel() async {
    final resultado = await _connectivity.checkConnectivity();
    return !resultado.contains(ConnectivityResult.none);
  }

  /// Faz um teste de conexão leve e rápido (timeout curto) para saber se a
  /// API configurada está realmente alcançável agora.
  Future<bool> apiEstaDisponivel() async {
    if (!await temRedeDisponivel()) return false;

    try {
      final uri = Uri.parse(AppConfig.instance.apiBaseUrl);
      final socket = await Socket.connect(
        uri.host,
        uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80),
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stream para a UI reagir a mudanças de conectividade (ex.: mostrar o
  /// banner "Modo offline").
  Stream<bool> get mudancasDeRede =>
      _connectivity.onConnectivityChanged.map((r) => !r.contains(ConnectivityResult.none));
}
