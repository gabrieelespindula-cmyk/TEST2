import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilitário simples de hash de senha, usado apenas no modo local/offline.
/// A API em nuvem (C#) continua usando BCrypt, como no projeto original.
class PasswordUtils {
  static const _salt = 'sabor_de_casa_salt_v1';

  static String hash(String senha) {
    final bytes = utf8.encode('$_salt::$senha');
    return sha256.convert(bytes).toString();
  }

  static bool verify(String senha, String hashSalvo) {
    return hash(senha) == hashSalvo;
  }
}
