import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/connectivity_service.dart';
import '../theme.dart';

/// Tela simples para configurar, direto no app, o endereço da API em
/// nuvem (sem precisar recompilar). Útil para alternar entre o servidor
/// local (durante o desenvolvimento) e o servidor publicado de verdade.
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _urlController = TextEditingController();
  final _connectivity = ConnectivityService();
  bool _testando = false;
  bool? _conectou;

  @override
  void initState() {
    super.initState();
    _urlController.text = AppConfig.instance.apiBaseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    await AppConfig.instance.salvarApiBaseUrl(_urlController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Endereço da API salvo.')));
    setState(() => _conectou = null);
  }

  Future<void> _testarConexao() async {
    await AppConfig.instance.salvarApiBaseUrl(_urlController.text);
    setState(() {
      _testando = true;
      _conectou = null;
    });
    final ok = await _connectivity.apiEstaDisponivel();
    if (!mounted) return;
    setState(() {
      _testando = false;
      _conectou = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conexão com a nuvem')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Informe o endereço da API em nuvem (ASP.NET Core) que o app vai usar '
              'quando houver internet. Sem conexão, o app continua funcionando '
              'normalmente com os dados salvos no próprio celular.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL da API',
                hintText: 'https://seu-app.exemplo.com',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dica: no emulador Android, "10.0.2.2" aponta para o localhost da '
              'sua máquina. Em um celular físico, use o IP da sua rede local '
              '(ex.: http://192.168.0.10:5000) ou a URL pública depois do deploy.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testando ? null : _testarConexao,
                    icon: _testando
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_tethering),
                    label: const Text('Testar conexão'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _salvar,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Salvar'),
                  ),
                ),
              ],
            ),
            if (_conectou != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (_conectou! ? AppColors.secondary : AppColors.danger).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(_conectou! ? Icons.check_circle_outline : Icons.error_outline,
                        color: _conectou! ? AppColors.secondary : AppColors.danger),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _conectou! ? 'Conectado com sucesso à API.' : 'Não foi possível conectar. Verifique o endereço e a rede.',
                        style: TextStyle(color: _conectou! ? AppColors.secondary : AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
