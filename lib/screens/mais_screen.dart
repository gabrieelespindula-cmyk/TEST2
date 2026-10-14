import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../services/session_provider.dart';
import '../services/sync_queue.dart';
import '../services/sync_service.dart';
import '../theme.dart';
import 'config_screen.dart';
import 'login_screen.dart';
import 'relatorios/relatorio_screen.dart';
import 'usuarios/usuario_list_screen.dart';

class MaisScreen extends StatefulWidget {
  const MaisScreen({super.key});

  @override
  State<MaisScreen> createState() => _MaisScreenState();
}

class _MaisScreenState extends State<MaisScreen> {
  final _fila = SyncQueue();
  final _connectivity = ConnectivityService();
  final _syncService = SyncService();

  int _pendentes = 0;
  bool _online = false;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _atualizarStatus();
  }

  Future<void> _atualizarStatus() async {
    final pendentes = await _fila.contarPendentes();
    final online = await _connectivity.apiEstaDisponivel();
    if (!mounted) return;
    setState(() {
      _pendentes = pendentes;
      _online = online;
    });
  }

  Future<void> _sincronizarAgora() async {
    setState(() => _sincronizando = true);
    final resultado = await _syncService.sincronizar();
    await _atualizarStatus();
    if (!mounted) return;
    setState(() => _sincronizando = false);

    final msg = resultado.sincronizados == 0 && resultado.falharam == 0
        ? (_online ? 'Nenhuma alteração pendente.' : 'Sem conexão com a nuvem no momento.')
        : '${resultado.sincronizados} sincronizada(s)${resultado.falharam > 0 ? ', ${resultado.falharam} com erro' : ''}.';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmarSair(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    await context.read<SessionProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final usuario = session.usuario;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _atualizarStatus,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary,
                        child: Text((usuario?.nome ?? '?').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(usuario?.nome ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text('@${usuario?.login ?? ''}', style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(session.isGerente ? 'Gerente' : 'Funcionário', style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status de conexão com a nuvem
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(_online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, color: _online ? AppColors.secondary : AppColors.warning),
                        const SizedBox(width: 8),
                        Text(_online ? 'Conectado à nuvem' : 'Modo offline', style: TextStyle(fontWeight: FontWeight.bold, color: _online ? AppColors.secondary : AppColors.warning)),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        _pendentes == 0
                            ? 'Tudo sincronizado.'
                            : '$_pendentes alteração(ões) aguardando envio para a nuvem.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _sincronizando ? null : _sincronizarAgora,
                              icon: _sincronizando
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.sync),
                              label: const Text('Sincronizar agora'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConfigScreen())),
                            icon: const Icon(Icons.settings_outlined),
                            tooltip: 'Configurar servidor',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (session.isGerente) ...[
                _MenuItem(icon: Icons.bar_chart_outlined, titulo: 'Relatórios de vendas', subtitulo: 'Filtrar vendas por período', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RelatorioScreen()))),
                const SizedBox(height: 10),
                _MenuItem(icon: Icons.people_outline, titulo: 'Usuários', subtitulo: 'Gerenciar acessos ao sistema', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UsuarioListScreen()))),
                const SizedBox(height: 10),
              ],
              _MenuItem(icon: Icons.logout, titulo: 'Sair', subtitulo: 'Encerrar sessão', cor: AppColors.danger, onTap: () => _confirmarSair(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  final Color cor;

  const _MenuItem({required this.icon, required this.titulo, required this.subtitulo, required this.onTap, this.cor = AppColors.textDark});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: cor),
        title: Text(titulo, style: TextStyle(color: cor, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
