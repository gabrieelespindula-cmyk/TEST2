import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'screens/login_screen.dart';
import 'services/session_provider.dart';
import 'theme.dart';
import 'widgets/main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SaborDeCasaApp());
}

class SaborDeCasaApp extends StatelessWidget {
  const SaborDeCasaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionProvider(),
      child: MaterialApp(
        title: 'Sabor de Casa',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _Bootstrap(),
      ),
    );
  }
}

/// Carrega a configuração salva (URL da API) e tenta restaurar uma sessão
/// anterior antes de decidir se mostra a tela de Login ou o app principal.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _pronto = false;
  bool _logado = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await AppConfig.instance.carregar();
    final logado = await context.read<SessionProvider>().restaurarSessao();
    if (!mounted) return;
    setState(() {
      _logado = logado;
      _pronto = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_pronto) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _logado ? const MainScaffold() : const LoginScreen();
  }
}
