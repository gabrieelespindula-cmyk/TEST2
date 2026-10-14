import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/produto.dart';
import '../../services/produto_service.dart';
import '../../services/session_provider.dart';
import '../../theme.dart';
import '../../utils/formatters.dart';
import 'produto_form_screen.dart';
import 'estoque_screen.dart';
import '../../services/data_notifier.dart';

class ProdutoListScreen extends StatefulWidget {
  const ProdutoListScreen({super.key});

  @override
  State<ProdutoListScreen> createState() => _ProdutoListScreenState();
}

class _ProdutoListScreenState extends State<ProdutoListScreen> {
  final _service = ProdutoService();
  final _buscaController = TextEditingController();

  List<Produto> _produtos = [];
  List<String> _categorias = [];
  String? _categoriaSelecionada;
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
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);
    final categorias = await _service.listarCategorias();
    final produtos = await _service.listar(busca: _buscaController.text, categoria: _categoriaSelecionada);
    if (!mounted) return;
    setState(() {
      _categorias = categorias;
      _produtos = produtos;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isGerente = context.watch<SessionProvider>().isGerente;

    return Scaffold(
      appBar: AppBar(title: const Text('Produtos')),
      floatingActionButton: isGerente
          ? FloatingActionButton.extended(
              onPressed: () async {
                final criado = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ProdutoFormScreen()));
                if (criado == true) _carregar();
              },
              icon: const Icon(Icons.add),
              label: const Text('Produto'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _buscaController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _carregar(),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nome...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _buscaController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.close), onPressed: () { _buscaController.clear(); _carregar(); })
                        : null,
                  ),
                ),
                if (_categorias.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _ChipCategoria(label: 'Todas', selecionado: _categoriaSelecionada == null, onTap: () { setState(() => _categoriaSelecionada = null); _carregar(); }),
                        ..._categorias.map((c) => _ChipCategoria(label: c, selecionado: _categoriaSelecionada == c, onTap: () { setState(() => _categoriaSelecionada = c); _carregar(); })),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _produtos.isEmpty
                    ? Center(child: Text('Nenhum produto encontrado.', style: TextStyle(color: Colors.grey.shade600)))
                    : RefreshIndicator(
                        onRefresh: _carregar,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                          itemCount: _produtos.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final p = _produtos[index];
                            return _ProdutoCard(
                              produto: p,
                              isGerente: isGerente,
                              onEditar: () async {
                                final editado = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ProdutoFormScreen(produto: p)));
                                if (editado == true) _carregar();
                              },
                              onEstoque: () async {
                                final ajustado = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EstoqueAjusteScreen(produtoInicial: p)));
                                if (ajustado == true) _carregar();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ChipCategoria extends StatelessWidget {
  final String label;
  final bool selecionado;
  final VoidCallback onTap;
  const _ChipCategoria({required this.label, required this.selecionado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selecionado,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: selecionado ? Colors.white : AppColors.textDark, fontWeight: FontWeight.w500),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }
}

class _ProdutoCard extends StatelessWidget {
  final Produto produto;
  final bool isGerente;
  final VoidCallback onEditar;
  final VoidCallback onEstoque;

  const _ProdutoCard({required this.produto, required this.isGerente, required this.onEditar, required this.onEstoque});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isGerente ? onEditar : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.fastfood_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(produto.nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(produto.categoria.isEmpty ? 'Sem categoria' : produto.categoria, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(Formatters.moeda(produto.preco), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (produto.estoqueBaixo ? AppColors.danger : AppColors.secondary).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${produto.quantidadeEstoque} un.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: produto.estoqueBaixo ? AppColors.danger : AppColors.secondary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isGerente) IconButton(icon: const Icon(Icons.inventory_2_outlined, color: AppColors.textDark), tooltip: 'Ajustar estoque', onPressed: onEstoque),
            ],
          ),
        ),
      ),
    );
  }
}
