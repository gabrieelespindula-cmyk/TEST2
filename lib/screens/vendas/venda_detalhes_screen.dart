import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/venda.dart';
import '../../services/session_provider.dart';
import '../../services/venda_service.dart';
import '../../theme.dart';
import '../../utils/formatters.dart';

class VendaDetalhesScreen extends StatefulWidget {
  final int vendaId;
  const VendaDetalhesScreen({super.key, required this.vendaId});

  @override
  State<VendaDetalhesScreen> createState() => _VendaDetalhesScreenState();
}

class _VendaDetalhesScreenState extends State<VendaDetalhesScreen> {
  final _service = VendaService();
  Venda? _venda;
  bool _alterou = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final venda = await _service.buscarPorId(widget.vendaId);
    if (!mounted) return;
    setState(() => _venda = venda);
  }

  Future<void> _cancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar venda?'),
        content: const Text('Os itens voltarão para o estoque. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar venda')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await _service.cancelar(widget.vendaId);
      _alterou = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Venda cancelada e estoque restaurado.')));
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGerente = context.watch<SessionProvider>().isGerente;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_alterou);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Venda #${widget.vendaId}')),
        body: _venda == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(Formatters.dataHora(_venda!.data), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: (_venda!.status == 'Cancelada' ? AppColors.danger : AppColors.secondary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                        child: Text(_venda!.status, style: TextStyle(color: _venda!.status == 'Cancelada' ? AppColors.danger : AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Vendedor: ${_venda!.usuario?.nome ?? '-'}'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('Itens', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ..._venda!.itens.map((item) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(item.produto?.nome ?? 'Produto #${item.produtoId}'),
                                  subtitle: Text('${item.quantidade} x ${Formatters.moeda(item.precoUnitario)}'),
                                  trailing: Text(Formatters.moeda(item.calcularSubtotal()), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              )),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))]),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                Text(Formatters.moeda(_venda!.valorTotal), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ],
                            ),
                            if (isGerente && _venda!.status != 'Cancelada') ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _cancelar,
                                icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                                label: const Text('Cancelar venda', style: TextStyle(color: AppColors.danger)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
