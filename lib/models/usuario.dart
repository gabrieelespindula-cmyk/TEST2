class Usuario {
  final int? id;
  final String nome;
  final String login;
  final String senhaHash;
  final String perfil; // "gerente" ou "funcionario"

  Usuario({
    this.id,
    required this.nome,
    required this.login,
    required this.senhaHash,
    required this.perfil,
  });

  bool get isGerente => perfil == 'gerente';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'login': login,
      'senha': senhaHash,
      'perfil': perfil,
    };
  }

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      login: map['login'] as String,
      senhaHash: (map['senha'] ?? '') as String,
      perfil: map['perfil'] as String,
    );
  }

  /// Payload vindo da API (sem expor hash de senha)
  factory Usuario.fromApiJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int?,
      nome: json['nome'] as String,
      login: json['login'] as String,
      senhaHash: '',
      perfil: json['perfil'] as String,
    );
  }

  Usuario copyWith({
    int? id,
    String? nome,
    String? login,
    String? senhaHash,
    String? perfil,
  }) {
    return Usuario(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      login: login ?? this.login,
      senhaHash: senhaHash ?? this.senhaHash,
      perfil: perfil ?? this.perfil,
    );
  }
}
