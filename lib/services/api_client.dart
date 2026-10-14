import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'token_storage.dart';

/// Exceção lançada quando a API responde com erro de negócio
/// (ex.: estoque insuficiente, login inválido).
class ApiException implements Exception {
  final String mensagem;
  final int? statusCode;
  ApiException(this.mensagem, {this.statusCode});
  @override
  String toString() => mensagem;
}

/// Exceção lançada quando não foi possível nem chegar na API
/// (sem internet, servidor fora do ar, timeout).
class ApiIndisponivelException implements Exception {
  final String mensagem;
  ApiIndisponivelException([this.mensagem = 'Servidor indisponível no momento.']);
  @override
  String toString() => mensagem;
}

/// Camada fina sobre o pacote `http`, responsável por:
/// - montar a URL a partir da configuração salva (AppConfig)
/// - anexar o token JWT (Authorization: Bearer ...) nas requisições
/// - converter JSON e tratar erros de forma padronizada
class ApiClient {
  final TokenStorage _tokenStorage = TokenStorage();
  static const _timeout = Duration(seconds: 8);

  Uri _montarUri(String path) => Uri.parse('${AppConfig.instance.apiBaseUrl}$path');

  Future<Map<String, String>> _headers({bool comAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (comAuth) {
      final token = await _tokenStorage.lerToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _tratarResposta(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }

    String mensagem = 'Erro ao comunicar com o servidor (${resp.statusCode}).';
    try {
      final corpo = jsonDecode(utf8.decode(resp.bodyBytes));
      if (corpo is Map && corpo['mensagem'] != null) {
        mensagem = corpo['mensagem'].toString();
      } else if (corpo is Map && corpo['title'] != null) {
        mensagem = corpo['title'].toString();
      }
    } catch (_) {
      // corpo não era JSON (ex.: erro 401 puro) — mantém mensagem padrão
    }
    throw ApiException(mensagem, statusCode: resp.statusCode);
  }

  Future<dynamic> get(String path) async {
    try {
      final resp = await http.get(_montarUri(path), headers: await _headers()).timeout(_timeout);
      return _tratarResposta(resp);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiIndisponivelException();
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body, {bool comAuth = true}) async {
    try {
      final resp = await http
          .post(_montarUri(path), headers: await _headers(comAuth: comAuth), body: jsonEncode(body))
          .timeout(_timeout);
      return _tratarResposta(resp);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiIndisponivelException();
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    try {
      final resp =
          await http.put(_montarUri(path), headers: await _headers(), body: jsonEncode(body)).timeout(_timeout);
      return _tratarResposta(resp);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiIndisponivelException();
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final resp = await http.delete(_montarUri(path), headers: await _headers()).timeout(_timeout);
      return _tratarResposta(resp);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiIndisponivelException();
    }
  }
}
