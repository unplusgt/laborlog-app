import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/app_config.dart';

/// Inicio de sesión: código de empresa + usuario o correo + contraseña.
/// El dueño de LaborLog entra con el código de empresa "plataforma".
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _servidor = TextEditingController(text: AppConfig.apiUrl);
  final _empresa = TextEditingController();
  final _usuario = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _verServidor = false;
  bool _verPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AuthService.ultimaEmpresa().then((e) {
      if (mounted && _empresa.text.isEmpty) setState(() => _empresa.text = e);
    });
  }

  @override
  void dispose() {
    for (final c in [_servidor, _empresa, _usuario, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _login() async {
    if (_empresa.text.trim().isEmpty || _usuario.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Completa empresa, usuario y contraseña');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await AppConfig.guardarApiUrl(_servidor.text);
    final ok = await AuthService().login(_empresa.text, _usuario.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushReplacementNamed(context, AuthService.isPlataforma ? '/plataforma' : '/home');
    } else {
      setState(() => _error = 'Empresa, usuario o contraseña incorrectos, o sin conexión con ${AppConfig.apiUrl}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LaborLog')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                Text('Iniciar sesión', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                TextField(
                  controller: _empresa,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Empresa',
                    hintText: 'código, p. ej. constructora-abc',
                    prefixIcon: Icon(Icons.business),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usuario,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Usuario o correo',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: !_verPassword,
                  onSubmitted: (_) => _loading ? null : _login(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _verPassword = !_verPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _verServidor = !_verServidor),
                    icon: Icon(_verServidor ? Icons.expand_less : Icons.dns, size: 18),
                    label: Text('Servidor: ${AppConfig.apiUrl}', overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (_verServidor)
                  TextField(
                    controller: _servidor,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Servidor',
                      hintText: 'http://192.168.0.12:8000',
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Iniciar sesión'),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/kiosco/activar'),
                  icon: const Icon(Icons.phonelink_lock),
                  label: const Text('Usar este teléfono como kiosco de obra'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
