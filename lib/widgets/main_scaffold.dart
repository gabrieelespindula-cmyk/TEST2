import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/mais_screen.dart';
import '../screens/produtos/produto_list_screen.dart';
import '../screens/vendas/venda_list_screen.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import 'connection_banner.dart';

/// Casca principal do app com navegação inferior, otimizada para celular:
/// no máximo 4 abas visíveis. Também é responsável por detectar quando a
/// conexão com a nuvem volta e disparar a sincronização automática.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _indiceAtual = 0;
  bool _online = false;
  StreamSubscription<bool>? _assinaturaRede;
  final _connectivity = ConnectivityService();
  final _syncService = SyncService();

  final _paginas = const [
    DashboardScreen(),
    ProdutoListScreen(),
    VendaListScreen(),
    MaisScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _verificarESincronizar();
    _assinaturaRede = _connectivity.mudancasDeRede.listen((temRede) {
      if (temRede) _verificarESincronizar();
      setState(() => _online = temRede);
    });
  }

  @override
  void dispose() {
    _assinaturaRede?.cancel();
    super.dispose();
  }

  Future<void> _verificarESincronizar() async {
    final disponivel = await _connectivity.apiEstaDisponivel();
    if (!mounted) return;
    setState(() => _online = disponivel);
    if (disponivel) {
      await _syncService.sincronizar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ConnectionBanner(online: _online),
          Expanded(child: IndexedStack(index: _indiceAtual, children: _paginas)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: (i) => setState(() => _indiceAtual = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.fastfood_outlined), selectedIcon: Icon(Icons.fastfood), label: 'Produtos'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Vendas'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
