import 'package:flutter/material.dart';
import '../../models/venda.dart';
import '../../services/dashboard_service.dart';
import '../../theme.dart';
import '../../utils/formatters.dart';
import '../vendas/venda_detalhes_screen.dart';

class RelatorioScreen extends StatefulWidget {
  const RelatorioScreen({super.key});

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  final _service = RelatorioService();
  List<Venda> _vendas = [];
  DateTime? _dataInicio;
  DateTime? _dataFim;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final vendas = await _service.gerar(dataInicio: _dataInicio, dataFim: _dataFim);
    if (!mounted) return;
    setState(() {
      _vendas = vendas;
      _carregando = false;
    });
  }

  Future<void> _selecionarData({required bool inicio}) async {
    final data = await showDatePicker(context: context, initialDate: (inicio ? _dataInicio : _dataFim) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (data == null) return;
    setState(() { if (inicio) { _dataInicio = data; } else { _dataFim = data; } });
    _carregar();
  }

  void _limparFiltros() {
    setState(() { _dataInicio = null; _dataFim = null; });
    _carregar();
  }

  double get _totalAtivas => _vendas.where((v) => v.status == 'Ativa').fold(0.0, (sum, v) => sum + v.valorTotal);
  int get _qtdAtivas => _vendas.where((v) => v.status == 'Ativa').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _FiltroDataBotao(label: 'De', data: _dataInicio, onTap: () => _selecionarData(inicio: true))),
                      const SizedBox(width: 10),
                      Expanded(child: _FiltroDataBotao(label: 'Até', data: _dataFim, onTap: () => _selecionarData(inicio: false))),
                      if (_dataInicio != null || _dataFim != null) IconButton(onPressed: _limparFiltros, icon: const Icon(Icons.filter_alt_off_outlined), tooltip: 'Limpar filtros'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _ResumoCard(titulo: 'Total (vendas ativas)', valor: Formatters.moeda(_totalAtivas), icon: Icons.payments_outlined)),
                      const SizedBox(width: 10),
                      Expanded(child: _ResumoCard(titulo: 'Qtd. de vendas', valor: '$_qtdAtivas', icon: Icons.receipt_long_outlined)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _vendas.isEmpty
                      ? Center(child: Text('Nenhuma venda no período.', style: TextStyle(color: Colors.grey.shade600)))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _vendas.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final v = _vendas[index];
                            final cancelada = v.status == 'Cancelada';
                            return Card(
                              child: ListTile(
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VendaDetalhesScreen(vendaId: v.id!))),
                                leading: Icon(cancelada ? Icons.cancel_outlined : Icons.check_circle_outline, color: cancelada ? AppColors.danger : AppColors.secondary),
                                title: Text('Venda #${v.id} • ${v.usuario?.nome ?? '-'}'),
                                subtitle: Text(Formatters.dataHora(v.data)),
                                trailing: Text(Formatters.moeda(v.valorTotal), style: TextStyle(fontWeight: FontWeight.bold, decoration: cancelada ? TextDecoration.lineThrough : null, color: cancelada ? Colors.grey : AppColors.textDark)),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltroDataBotao extends StatelessWidget {
  final String label;
  final DateTime? data;
  final VoidCallback onTap;
  const _FiltroDataBotao({required this.label, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(data != null ? Formatters.dataCurta(data!) : label, style: TextStyle(color: data != null ? AppColors.textDark : Colors.grey.shade500, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icon;
  const _ResumoCard({required this.titulo, required this.valor, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(titulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
