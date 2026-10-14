import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/dashboard_service.dart';
import '../services/session_provider.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'produtos/estoque_screen.dart';
import 'vendas/venda_registrar_screen.dart';
import '../services/data_notifier.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = DashboardService();
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.carregar();
    DataNotifier.versao.addListener(_aoMudarDados);
  }

  void _aoMudarDados() {
    if (mounted) setState(() => _future = _service.carregar());
  }

  @override
  void dispose() {
    DataNotifier.versao.removeListener(_aoMudarDados);
    super.dispose();
  }

  Future<void> _recarregar() async {
    setState(() => _future = _service.carregar());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<SessionProvider>().usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sabor de Casa'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _recarregar)],
      ),
      body: RefreshIndicator(
        onRefresh: _recarregar,
        child: FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final data = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Olá, ${usuario?.nome.split(' ').first ?? ''} 👋', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(Formatters.dataCurta(DateTime.now()), style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _IndicadorCard(titulo: 'Vendas hoje', valor: Formatters.moeda(data.totalVendasHoje), subtitulo: '${data.quantidadeVendasHoje} venda(s)', icon: Icons.point_of_sale, cor: AppColors.primary)),
                    const SizedBox(width: 12),
                    Expanded(child: _IndicadorCard(titulo: 'Vendas no mês', valor: Formatters.moeda(data.totalVendasMes), subtitulo: 'Total acumulado', icon: Icons.calendar_month, cor: AppColors.secondary)),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VendaRegistrarScreen())),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Nova venda'),
                      ),
                    ),
                    if (usuario?.isGerente ?? false) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EstoqueAjusteScreen())),
                          icon: const Icon(Icons.inventory_2_outlined),
                          label: const Text('Estoque'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                if (data.produtosEstoqueBaixo.isNotEmpty) ...[
                  Row(children: const [
                    Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                    SizedBox(width: 6),
                    Text('Estoque baixo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: data.produtosEstoqueBaixo.map((p) {
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.inventory, color: AppColors.warning),
                            title: Text(p.nome),
                            trailing: Text('${p.quantidadeEstoque} un.', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (data.produtosMaisVendidos.isNotEmpty) ...[
                  const Text('Mais vendidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: data.produtosMaisVendidos.asMap().entries.map((entry) {
                          final i = entry.key;
                          final p = entry.value;
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text('${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            title: Text(p.nomeProduto),
                            trailing: Text('${p.quantidadeVendida} un.'),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IndicadorCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String subtitulo;
  final IconData icon;
  final Color cor;

  const _IndicadorCard({required this.titulo, required this.valor, required this.subtitulo, required this.icon, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cor, size: 22),
            const SizedBox(height: 10),
            Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
