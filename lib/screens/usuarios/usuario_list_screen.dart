import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/usuario.dart';
import '../../services/session_provider.dart';
import '../../services/usuario_service.dart';
import '../../theme.dart';
import 'usuario_form_screen.dart';

class UsuarioListScreen extends StatefulWidget {
  const UsuarioListScreen({super.key});

  @override
  State<UsuarioListScreen> createState() => _UsuarioListScreenState();
}

class _UsuarioListScreenState extends State<UsuarioListScreen> {
  final _service = UsuarioService();
  List<Usuario> _usuarios = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final lista = await _service.listar();
    if (!mounted) return;
    setState(() {
      _usuarios = lista;
      _carregando = false;
    });
  }

  Future<void> _excluir(Usuario usuario) async {
    final usuarioLogado = context.read<SessionProvider>().usuario!;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover usuário?'),
        content: Text('Deseja remover "${usuario.nome}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await _service.excluir(usuario.id!, usuarioLogadoId: usuarioLogado.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário removido com sucesso.')));
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarioLogadoId = context.watch<SessionProvider>().usuario?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Usuários')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final criado = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const UsuarioFormScreen()));
          if (criado == true) _carregar();
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Usuário'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: _usuarios.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final u = _usuarios[index];
                  final ehVoce = u.id == usuarioLogadoId;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (u.isGerente ? AppColors.primary : AppColors.secondary).withValues(alpha: 0.12),
                        child: Icon(u.isGerente ? Icons.admin_panel_settings_outlined : Icons.person_outline, color: u.isGerente ? AppColors.primary : AppColors.secondary),
                      ),
                      title: Text(u.nome + (ehVoce ? ' (você)' : '')),
                      subtitle: Text('@${u.login} • ${u.isGerente ? 'Gerente' : 'Funcionário'}'),
                      trailing: ehVoce ? null : IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: () => _excluir(u)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
