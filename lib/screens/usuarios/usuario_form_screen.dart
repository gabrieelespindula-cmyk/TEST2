import 'package:flutter/material.dart';
import '../../services/usuario_service.dart';

class UsuarioFormScreen extends StatefulWidget {
  const UsuarioFormScreen({super.key});

  @override
  State<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends State<UsuarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = UsuarioService();

  final _nomeController = TextEditingController();
  final _loginController = TextEditingController();
  final _senhaController = TextEditingController();
  String _perfil = 'funcionario';
  bool _salvando = false;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _loginController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);

    try {
      await _service.criar(nome: _nomeController.text.trim(), login: _loginController.text.trim(), senha: _senhaController.text, perfil: _perfil);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário cadastrado com sucesso!')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo Usuário')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.badge_outlined)),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nome é obrigatório' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _loginController,
                decoration: const InputDecoration(labelText: 'Login', prefixIcon: Icon(Icons.alternate_email)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Login é obrigatório' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _senhaController,
                obscureText: !_senhaVisivel,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel)),
                ),
                validator: (v) => (v == null || v.length < 4) ? 'Mínimo de 4 caracteres' : null,
              ),
              const SizedBox(height: 20),
              const Text('Perfil de acesso', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'funcionario', label: Text('Funcionário'), icon: Icon(Icons.person_outline)),
                  ButtonSegment(value: 'gerente', label: Text('Gerente'), icon: Icon(Icons.admin_panel_settings_outlined)),
                ],
                selected: {_perfil},
                onSelectionChanged: (v) => setState(() => _perfil = v.first),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Cadastrar usuário'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
