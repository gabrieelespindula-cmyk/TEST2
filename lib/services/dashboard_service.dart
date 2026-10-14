import '../db/database_helper.dart';
import '../models/produto.dart';
import '../models/venda.dart';
import 'api_client.dart';
import 'connectivity_service.dart';
import 'venda_service.dart';

class ProdutoMaisVendido {
  final String nomeProduto;
  final int quantidadeVendida;
  ProdutoMaisVendido({required this.nomeProduto, required this.quantidadeVendida});

  factory ProdutoMaisVendido.fromApiJson(Map<String, dynamic> json) => ProdutoMaisVendido(
        nomeProduto: json['nomeProduto'] as String,
        quantidadeVendida: (json['quantidadeVendida'] as num).toInt(),
      );
}

class DashboardData {
  final double totalVendasHoje;
  final double totalVendasMes;
  final int quantidadeVendasHoje;
  final List<Produto> produtosEstoqueBaixo;
  final List<ProdutoMaisVendido> produtosMaisVendidos;

  DashboardData({
    required this.totalVendasHoje,
    required this.totalVendasMes,
    required this.quantidadeVendasHoje,
    required this.produtosEstoqueBaixo,
    required this.produtosMaisVendidos,
  });
}

class DashboardService {
  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();

  // RF16 - Dashboard com indicadores
  Future<DashboardData> carregar() async {
    if (await _connectivity.apiEstaDisponivel()) {
      try {
        final json = await _api.get('/api/dashboard') as Map<String, dynamic>;
        return DashboardData(
          totalVendasHoje: (json['totalVendasHoje'] as num).toDouble(),
          totalVendasMes: (json['totalVendasMes'] as num).toDouble(),
          quantidadeVendasHoje: json['quantidadeVendasHoje'] as int,
          produtosEstoqueBaixo: (json['produtosEstoqueBaixo'] as List<dynamic>)
              .map((p) => Produto.fromApiJson(p as Map<String, dynamic>))
              .toList(),
          produtosMaisVendidos: (json['produtosMaisVendidos'] as List<dynamic>)
              .map((p) => ProdutoMaisVendido.fromApiJson(p as Map<String, dynamic>))
              .toList(),
        );
      } on ApiIndisponivelException {
        // cai para o cálculo local abaixo
      }
    }
    return _calcularLocal();
  }

  Future<DashboardData> _calcularLocal() async {
    final db = await DatabaseHelper.instance.database;
    final hoje = DateTime.now();
    final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
    final inicioMes = DateTime(hoje.year, hoje.month, 1);

    final vendasAtivasRaw = await db.query('vendas', where: 'status = ?', whereArgs: ['Ativa']);

    double totalHoje = 0;
    double totalMes = 0;
    int qtdHoje = 0;

    for (final v in vendasAtivasRaw) {
      final data = DateTime.parse(v['data'] as String);
      final valor = (v['valorTotal'] as num).toDouble();
      if (!data.isBefore(inicioHoje)) {
        totalHoje += valor;
        qtdHoje++;
      }
      if (!data.isBefore(inicioMes)) {
        totalMes += valor;
      }
    }

    final estoqueBaixoRaw = await db.query(
      'produtos',
      where: 'quantidadeEstoque < ?',
      whereArgs: [20],
      orderBy: 'quantidadeEstoque ASC',
    );
    final produtosEstoqueBaixo = estoqueBaixoRaw.map((m) => Produto.fromMap(m)).toList();

    final topRaw = await db.rawQuery('''
      SELECT p.nome as nomeProduto, SUM(iv.quantidade) as totalQuantidade
      FROM itens_venda iv
      JOIN vendas v ON v.id = iv.vendaId
      JOIN produtos p ON p.id = iv.produtoId
      WHERE v.status = 'Ativa'
      GROUP BY p.nome
      ORDER BY totalQuantidade DESC
      LIMIT 5
    ''');

    final produtosMaisVendidos = topRaw
        .map((m) => ProdutoMaisVendido(
              nomeProduto: m['nomeProduto'] as String,
              quantidadeVendida: (m['totalQuantidade'] as num).toInt(),
            ))
        .toList();

    return DashboardData(
      totalVendasHoje: totalHoje,
      totalVendasMes: totalMes,
      quantidadeVendasHoje: qtdHoje,
      produtosEstoqueBaixo: produtosEstoqueBaixo,
      produtosMaisVendidos: produtosMaisVendidos,
    );
  }
}

class RelatorioService {
  final ApiClient _api = ApiClient();
  final ConnectivityService _connectivity = ConnectivityService();
  final _vendaService = VendaService();

  // RF10, RF15 - Relatório de vendas com filtro por período
  Future<List<Venda>> gerar({DateTime? dataInicio, DateTime? dataFim}) async {
    if (await _connectivity.apiEstaDisponivel()) {
      try {
        final query = <String>[];
        if (dataInicio != null) query.add('dataInicio=${dataInicio.toIso8601String()}');
        if (dataFim != null) query.add('dataFim=${dataFim.toIso8601String()}');
        final path = '/api/relatorio${query.isNotEmpty ? '?${query.join('&')}' : ''}';
        final resposta = await _api.get(path) as List<dynamic>;
        return resposta.map((j) => Venda.fromApiJson(j as Map<String, dynamic>)).toList();
      } on ApiIndisponivelException {
        // cai para o filtro local abaixo
      }
    }

    final todas = await _vendaService.listar();
    return todas.where((v) {
      if (dataInicio != null && v.data.isBefore(dataInicio)) return false;
      if (dataFim != null && v.data.isAfter(dataFim.add(const Duration(days: 1)))) return false;
      return true;
    }).toList();
  }
}
