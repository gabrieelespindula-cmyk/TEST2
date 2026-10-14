import 'package:flutter/material.dart';
import '../../models/produto.dart';
import '../../services/produto_service.dart';
import '../../theme.dart';

class EstoqueAjusteScreen extends StatefulWidget {
  final Produto? produtoInicial;
  const EstoqueAjusteScreen({super.key, this.produtoInicial});

  @override
  State<EstoqueAjusteScreen> createState() => _EstoqueAjusteScreenState();
}

class _EstoqueAjusteScreenState extends State<EstoqueAjusteScreen> {
  final _service = ProdutoService();
  final _quantidadeController = TextEditingController();

  Produto? _produtoSelecionado;
  List<Produto> _produtos = [];
  bool _entrada = true;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _produtoSelecionado = widget.produtoInicial;
    _carregarProdutos();
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    final lista = await _service.listar();
    if (!mounted) return;
    setState(() {
      _produtos = lista;
      _carregando = false;
      if (_produtoSelecionado != null) {
        _produtoSelecionado = lista.firstWhere((p) => p.id == _produtoSelecionado!.id, orElse: () => _produtoSelecionado!);
      }
    });
  }

  Future<void> _confirmar() async {
    if (_produtoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um produto.')));
      return;
    }
    final quantidade = int.tryParse(_quantidadeController.text);
    if (quantidade == null || quantidade <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe uma quantidade válida.')));
      return;
    }

    setState(() => _salvando = true);
    try {
      final ajuste = _entrada ? quantidade : -quantidade;
      final atualizado = await _service.atualizarEstoque(_produtoSelecionado!.id!, ajuste);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estoque atualizado! Novo total: ${atualizado.quantidadeEstoque} unidades.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atualizar Estoque')),
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<Produto>(
                    value: _produtos.any((p) => p.id == _produtoSelecionado?.id) ? _produtos.firstWhere((p) => p.id == _produtoSelecionado?.id) : null,
                    decoration: const InputDecoration(labelText: 'Produto', prefixIcon: Icon(Icons.fastfood_outlined)),
                    isExpanded: true,
                    items: _produtos.map((p) => DropdownMenuItem(value: p, child: Text('${p.nome} (atual: ${p.quantidadeEstoque})', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (p) => setState(() => _produtoSelecionado = p),
                  ),
                  const SizedBox(height: 20),
                  if (_produtoSelecionado != null)
                    Card(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Estoque atual: ${_produtoSelecionado!.quantidadeEstoque} unidades', style: const TextStyle(fontWeight: FontWeight.w500))),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _TipoBotao(label: 'Entrada (+)', icon: Icons.add_circle_outline, selecionado: _entrada, cor: AppColors.secondary, onTap: () => setState(() => _entrada = true))),
                      const SizedBox(width: 10),
                      Expanded(child: _TipoBotao(label: 'Saída (-)', icon: Icons.remove_circle_outline, selecionado: !_entrada, cor: AppColors.danger, onTap: () => setState(() => _entrada = false))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(controller: _quantidadeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade', prefixIcon: Icon(Icons.numbers))),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _salvando ? null : _confirmar,
                    child: _salvando
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Confirmar atualização'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TipoBotao extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selecionado;
  final Color cor;
  final VoidCallback onTap;

  const _TipoBotao({required this.label, required this.icon, required this.selecionado, required this.cor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selecionado ? cor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selecionado ? cor : Colors.grey.shade300, width: selecionado ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selecionado ? cor : Colors.grey.shade500),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: selecionado ? cor : Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }
}
