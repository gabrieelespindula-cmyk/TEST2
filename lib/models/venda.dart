import 'produto.dart';
import 'usuario.dart';

class ItemVenda {
  final int? id;
  final int? vendaId;
  final int produtoId;
  final Produto? produto;
  final int quantidade;
  final double precoUnitario;

  ItemVenda({
    this.id,
    this.vendaId,
    required this.produtoId,
    this.produto,
    required this.quantidade,
    required this.precoUnitario,
  });

  double calcularSubtotal() => quantidade * precoUnitario;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendaId': vendaId,
      'produtoId': produtoId,
      'quantidade': quantidade,
      'precoUnitario': precoUnitario,
    };
  }

  factory ItemVenda.fromMap(Map<String, dynamic> map, {Produto? produto}) {
    return ItemVenda(
      id: map['id'] as int?,
      vendaId: map['vendaId'] as int?,
      produtoId: map['produtoId'] as int,
      produto: produto,
      quantidade: map['quantidade'] as int,
      precoUnitario: (map['precoUnitario'] as num).toDouble(),
    );
  }

  factory ItemVenda.fromApiJson(Map<String, dynamic> json) {
    return ItemVenda(
      id: json['id'] as int?,
      vendaId: json['vendaId'] as int?,
      produtoId: json['produtoId'] as int,
      produto: json['produto'] != null ? Produto.fromApiJson(json['produto']) : null,
      quantidade: json['quantidade'] as int,
      precoUnitario: (json['precoUnitario'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'produtoId': produtoId,
      'quantidade': quantidade,
    };
  }
}

class Venda {
  final int? id;
  final DateTime data;
  final double valorTotal;
  final String status; // "Ativa" ou "Cancelada"
  final int usuarioId;
  final Usuario? usuario;
  final List<ItemVenda> itens;
  /// Id temporário usado apenas localmente enquanto a venda não foi
  /// sincronizada com a nuvem (ver [SyncService]).
  final String? uuidLocal;

  Venda({
    this.id,
    DateTime? data,
    this.valorTotal = 0,
    this.status = 'Ativa',
    required this.usuarioId,
    this.usuario,
    List<ItemVenda>? itens,
    this.uuidLocal,
  })  : data = data ?? DateTime.now(),
        itens = itens ?? [];

  double calcularTotal() => itens.fold(0.0, (sum, i) => sum + i.calcularSubtotal());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'data': data.toIso8601String(),
      'valorTotal': valorTotal,
      'status': status,
      'usuarioId': usuarioId,
    };
  }

  factory Venda.fromMap(Map<String, dynamic> map, {Usuario? usuario, List<ItemVenda>? itens}) {
    return Venda(
      id: map['id'] as int?,
      data: DateTime.parse(map['data'] as String),
      valorTotal: (map['valorTotal'] as num).toDouble(),
      status: map['status'] as String,
      usuarioId: map['usuarioId'] as int,
      usuario: usuario,
      itens: itens,
    );
  }

  factory Venda.fromApiJson(Map<String, dynamic> json) {
    return Venda(
      id: json['id'] as int?,
      data: DateTime.parse(json['data'] as String),
      valorTotal: (json['valorTotal'] as num).toDouble(),
      status: json['status'] as String,
      usuarioId: json['usuarioId'] as int,
      usuario: json['usuario'] != null ? Usuario.fromApiJson(json['usuario']) : null,
      itens: (json['itens'] as List<dynamic>?)
              ?.map((e) => ItemVenda.fromApiJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Payload enviado para POST /api/venda (o backend recalcula o total e
  /// a baixa de estoque, então só mandamos os itens desejados)
  Map<String, dynamic> toApiRegistrarJson() {
    return {
      'itens': itens.map((i) => i.toApiJson()).toList(),
    };
  }

  Venda copyWith({int? id, String? status}) {
    return Venda(
      id: id ?? this.id,
      data: data,
      valorTotal: valorTotal,
      status: status ?? this.status,
      usuarioId: usuarioId,
      usuario: usuario,
      itens: itens,
      uuidLocal: uuidLocal,
    );
  }
}
