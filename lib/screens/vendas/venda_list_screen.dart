import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/venda.dart';
import '../../services/session_provider.dart';
import '../../services/venda_service.dart';
import '../../theme.dart';
import '../../utils/formatters.dart';
import 'venda_detalhes_screen.dart';
import 'venda_registrar_screen.dart';
import '../../services/data_notifier.dart';

class VendaListScreen extends StatefulWidget {
  const VendaListScreen({super.key});

  @override
  State<VendaListScreen> createState() => _VendaListScreenState();
}

class _VendaListScreenState extends State<VendaListScreen> {
  final _service = VendaService();
  List<Venda> _vendas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
    DataNotifier.versao.addListener(_aoMudarDados);
  }

  void _aoMudarDados() {
    if (mounted) _carregar(silencioso: true);
  }

  @override
  void dispose() {
    DataNotifier.versao.removeListener(_aoMudarDados);
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);
    final vendas = await _service.listar();
    if (!mounted) return;
    setState(() {
      _vendas = vendas;
      _carregando = false;
    });
  }

  Future<void> _confirmarCancelamento(Venda venda) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar venda?'),
        content: Text('A venda #${venda.id} de ${Formatters.moeda(venda.valorTotal)} será cancelada e os itens voltarão para o estoque. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar venda')),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _service.cancelar(venda.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venda cancelada e estoque restaurado.')));
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGerente = context.watch<SessionProvider>().isGerente;

    return Scaffold(
      appBar: AppBar(title: const Text('Vendas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final registrou = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const VendaRegistrarScreen()));
          if (registrou == true) _carregar();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova venda'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _vendas.isEmpty
              ? Center(child: Text('Nenhuma venda registrada.', style: TextStyle(color: Colors.grey.shade600)))
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _vendas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final v = _vendas[index];
                      final cancelada = v.status == 'Cancelada';

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final alterou = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => VendaDetalhesScreen(vendaId: v.id!)));
                            if (alterou == true) _carregar();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(color: (cancelada ? AppColors.danger : AppColors.secondary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(cancelada ? Icons.cancel_outlined : Icons.receipt_long, color: cancelada ? AppColors.danger : AppColors.secondary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text('Venda #${v.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        if (cancelada)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                            child: const Text('Cancelada', style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                      ]),
                                      const SizedBox(height: 2),
                                      Text('${Formatters.dataHora(v.data)} • ${v.usuario?.nome ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(Formatters.moeda(v.valorTotal), style: TextStyle(fontWeight: FontWeight.bold, decoration: cancelada ? TextDecoration.lineThrough : null, color: cancelada ? Colors.grey : AppColors.textDark)),
                                    if (isGerente && !cancelada)
                                      InkWell(
                                        onTap: () => _confirmarCancelamento(v),
                                        child: const Padding(padding: EdgeInsets.only(top: 4), child: Text('Cancelar', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600))),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
