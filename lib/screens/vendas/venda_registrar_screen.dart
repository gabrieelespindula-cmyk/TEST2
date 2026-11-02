import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/produto.dart';
import '../../services/produto_service.dart';
import '../../services/session_provider.dart';
import '../../services/venda_service.dart';
import '../../theme.dart';
import '../../utils/formatters.dart';

class VendaRegistrarScreen extends StatefulWidget {
  const VendaRegistrarScreen({super.key});

  @override
  State<VendaRegistrarScreen> createState() => _VendaRegistrarScreenState();
}

class _VendaRegistrarScreenState extends State<VendaRegistrarScreen> {
  final _produtoService = ProdutoService();
  final _vendaService = VendaService();
  final _buscaController = TextEditingController();

  List<Produto> _produtosDisponiveis = [];
  final Map<int, ItemCarrinho> _carrinho = {};
  bool _carregando = true;
  bool _finalizando = false;

  double get _total => _carrinho.values.fold(0.0, (sum, i) => sum + i.subtotal);
  int get _totalItens => _carrinho.values.fold(0, (sum, i) => sum + i.quantidade);

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarProdutos() async {
    final lista = await _produtoService.listar(busca: _buscaController.text);
    if (!mounted) return;
    setState(() {
      _produtosDisponiveis = lista.where((p) => p.quantidadeEstoque > 0).toList();
      _carregando = false;
    });
  }

  void _adicionar(Produto p) {
    setState(() {
      final item = _carrinho[p.id];
      if (item != null) {
        if (item.quantidade < p.quantidadeEstoque) {
          item.quantidade++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Estoque máximo atingido para ${p.nome} (${p.quantidadeEstoque} un.)')));
        }
      } else {
        _carrinho[p.id!] = ItemCarrinho(produto: p, quantidade: 1);
      }
    });
  }

  void _remover(Produto p) {
    setState(() {
      final item = _carrinho[p.id];
      if (item == null) return;
      if (item.quantidade > 1) {
        item.quantidade--;
      } else {
        _carrinho.remove(p.id);
      }
    });
  }

  // NOVO: Método para abrir o diálogo e escolher a quantidade exata
  void _alterarQuantidadeDireta(Produto p) {
    final qtdAtual = _carrinho[p.id]?.quantidade ?? 0;
    final controller = TextEditingController(text: qtdAtual > 0 ? '$qtdAtual' : '1');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Quantidade para ${p.nome}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Disponível em estoque: ${p.quantidadeEstoque}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final novaQtd = int.tryParse(controller.text);
                if (novaQtd == null || novaQtd < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite um número válido.')));
                  return;
                }
                if (novaQtd > p.quantidadeEstoque) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quantidade excede o estoque disponível (${p.quantidadeEstoque} un.).')));
                  return;
                }

                setState(() {
                  if (novaQtd == 0) {
                    _carrinho.remove(p.id);
                  } else if (_carrinho.containsKey(p.id)) {
                    _carrinho[p.id]!.quantidade = novaQtd;
                  } else {
                    _carrinho[p.id!] = ItemCarrinho(produto: p, quantidade: novaQtd);
                  }
                });

                Navigator.pop(context);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _finalizarVenda() async {
    if (_carrinho.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adicione pelo menos um produto à venda.')));
      return;
    }

    final usuario = context.read<SessionProvider>().usuario;
    if (usuario == null) return;

    setState(() => _finalizando = true);
    try {
      final venda = await _vendaService.registrar(usuarioId: usuario.id!, carrinho: _carrinho.values.toList());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Venda registrada! Total: ${Formatters.moeda(venda.valorTotal)}')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Venda')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _buscaController,
                onChanged: (_) => _carregarProdutos(),
                decoration: InputDecoration(
                  hintText: 'Buscar produto...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _buscaController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () { _buscaController.clear(); _carregarProdutos(); }) : null,
                ),
              ),
            ),
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _produtosDisponiveis.isEmpty
                      ? Center(child: Text('Nenhum produto disponível.', style: TextStyle(color: Colors.grey.shade600)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _produtosDisponiveis.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final p = _produtosDisponiveis[index];
                            final qtdNoCarrinho = _carrinho[p.id]?.quantidade ?? 0;
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('${Formatters.moeda(p.preco)}  •  ${p.quantidadeEstoque} em estoque', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    if (qtdNoCarrinho == 0)
                                      IconButton.filled(
                                        onPressed: () => _alterarQuantidadeDireta(p), // Alterado para abrir o diálogo direto
                                        icon: const Icon(Icons.add), 
                                        style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                                        tooltip: 'Adicionar quantidade',
                                      )
                                    else
                                      Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(onPressed: () => _remover(p), icon: const Icon(Icons.remove_circle_outline), color: AppColors.danger),
                                        // Ao clicar no número, também abre o diálogo para digitar direto
                                        InkWell(
                                          onTap: () => _alterarQuantidadeDireta(p),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Text('$qtdNoCarrinho', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          ),
                                        ),
                                        IconButton(onPressed: () => _adicionar(p), icon: const Icon(Icons.add_circle_outline), color: AppColors.secondary),
                                      ]),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            if (_carrinho.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, -2))]),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$_totalItens item(ns)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            Text(Formatters.moeda(_total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: ElevatedButton.icon(
                          onPressed: _finalizando ? null : _finalizarVenda,
                          icon: _finalizando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
                          label: const Text('Finalizar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
