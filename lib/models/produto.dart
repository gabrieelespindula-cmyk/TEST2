class Produto {
  final int? id;
  final String nome;
  final double preco;
  final int quantidadeEstoque;
  final String categoria;

  Produto({
    this.id,
    required this.nome,
    required this.preco,
    required this.quantidadeEstoque,
    required this.categoria,
  });

  // RF12 - Alerta de estoque baixo (<20)
  bool get estoqueBaixo => quantidadeEstoque < 20;

  bool validarDisponibilidade(int qtdDesejada) => quantidadeEstoque >= qtdDesejada;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'preco': preco,
      'quantidadeEstoque': quantidadeEstoque,
      'categoria': categoria,
    };
  }

  factory Produto.fromMap(Map<String, dynamic> map) {
    return Produto(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      preco: (map['preco'] as num).toDouble(),
      quantidadeEstoque: map['quantidadeEstoque'] as int,
      categoria: map['categoria'] as String? ?? '',
    );
  }

  factory Produto.fromApiJson(Map<String, dynamic> json) {
    return Produto(
      id: json['id'] as int?,
      nome: json['nome'] as String,
      preco: (json['preco'] as num).toDouble(),
      quantidadeEstoque: json['quantidadeEstoque'] as int,
      categoria: json['categoria'] as String? ?? '',
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'id': id,
      'nome': nome,
      'preco': preco,
      'quantidadeEstoque': quantidadeEstoque,
      'categoria': categoria,
    };
  }

  Produto copyWith({
    int? id,
    String? nome,
    double? preco,
    int? quantidadeEstoque,
    String? categoria,
  }) {
    return Produto(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      preco: preco ?? this.preco,
      quantidadeEstoque: quantidadeEstoque ?? this.quantidadeEstoque,
      categoria: categoria ?? this.categoria,
    );
  }
}
