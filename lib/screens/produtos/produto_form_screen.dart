import 'package:flutter/material.dart';
import '../../models/produto.dart';
import '../../services/produto_service.dart';

class ProdutoFormScreen extends StatefulWidget {
  final Produto? produto;
  const ProdutoFormScreen({super.key, this.produto});

  @override
  State<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends State<ProdutoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ProdutoService();

  late final TextEditingController _nomeController;
  late final TextEditingController _precoController;
  late final TextEditingController _estoqueController;
  late final TextEditingController _categoriaController;

  bool _salvando = false;
  bool _excluindo = false;
  bool get _editando => widget.produto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.produto;
    _nomeController = TextEditingController(text: p?.nome ?? '');
    _precoController = TextEditingController(text: p != null ? p.preco.toStringAsFixed(2) : '');
    _estoqueController = TextEditingController(text: p != null ? p.quantidadeEstoque.toString() : '0');
    _categoriaController = TextEditingController(text: p?.categoria ?? '');
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _precoController.dispose();
    _estoqueController.dispose();
    _categoriaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    final preco = double.parse(_precoController.text.replaceAll(',', '.'));
    final estoque = int.parse(_estoqueController.text);

    try {
      if (_editando) {
        final atualizado = widget.produto!.copyWith(
          nome: _nomeController.text.trim(),
          preco: preco,
          quantidadeEstoque: estoque,
          categoria: _categoriaController.text.trim(),
        );
        await _service.atualizar(atualizado);
      } else {
        final novo = Produto(
          nome: _nomeController.text.trim(), 
          preco: preco, 
          quantidadeEstoque: estoque, 
          categoria: _categoriaController.text.trim(),
        );
        await _service.criar(novo);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editando ? 'Produto atualizado com sucesso!' : 'Produto cadastrado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao salvar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // Função para excluir o produto no APK via API
  Future<void> _excluir() async {
    if (widget.produto?.id == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Produto'),
        content: const Text('Tem certeza de que deseja excluir este produto do estoque?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _excluindo = true);

    try {
      // Certifique-se de que o seu ProdutoService possui o método excluir(int id) implementado
      await _service.excluir(widget.produto!.id!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produto excluído com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao excluir: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar Produto' : 'Novo Produto')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.label_outline)),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nome é obrigatório' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _precoController,
                decoration: const InputDecoration(labelText: 'Preço (R\$)', prefixIcon: Icon(Icons.attach_money)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Preço é obrigatório';
                  final valor = double.tryParse(v.replaceAll(',', '.'));
                  if (valor == null || valor <= 0) return 'Preço deve ser maior que zero';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _estoqueController,
                decoration: const InputDecoration(labelText: 'Quantidade em Estoque', prefixIcon: Icon(Icons.inventory_2_outlined)),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Quantidade é obrigatória';
                  final valor = int.tryParse(v);
                  if (valor == null || valor < 0) return 'Quantidade não pode ser negativa';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _categoriaController,
                decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined)),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 28),
              
              // Botão Salvar / Cadastrar
              ElevatedButton(
                onPressed: (_salvando || _excluindo) ? null : _salvar,
                child: _salvando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Text(_editando ? 'Salvar alterações' : 'Cadastrar produto'),
              ),

              // Botão Excluir (Aparece apenas se estiver editando um produto existente)
              if (_editando) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_salvando || _excluindo) ? null : _excluir,
                  icon: _excluindo
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.delete),
                  label: const Text('Excluir Produto'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
