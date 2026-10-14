import 'package:flutter/material.dart';
import '../services/sync_queue.dart';
import '../theme.dart';

/// Faixa fina mostrada no topo das telas quando o app está em modo
/// offline, com a quantidade de operações aguardando sincronização.
class ConnectionBanner extends StatefulWidget {
  final bool online;
  const ConnectionBanner({super.key, required this.online});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  final _fila = SyncQueue();
  int _pendentes = 0;

  @override
  void initState() {
    super.initState();
    _carregarPendentes();
  }

  @override
  void didUpdateWidget(covariant ConnectionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.online != widget.online) _carregarPendentes();
  }

  Future<void> _carregarPendentes() async {
    final total = await _fila.contarPendentes();
    if (mounted) setState(() => _pendentes = total);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.online && _pendentes == 0) return const SizedBox.shrink();

    final cor = widget.online ? AppColors.secondary : AppColors.warning;
    final texto = widget.online
        ? 'Sincronizando $_pendentes alteração(ões) pendente(s)...'
        : _pendentes > 0
            ? 'Modo offline • $_pendentes alteração(ões) aguardando sincronização'
            : 'Modo offline • usando dados salvos no celular';

    return Container(
      width: double.infinity,
      color: cor.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Icon(widget.online ? Icons.sync : Icons.cloud_off_outlined, size: 16, color: cor),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: TextStyle(fontSize: 12, color: cor, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
