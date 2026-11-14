import 'package:flutter/material.dart';

import '../services/sync_service.dart';
import '../utils/app_config.dart';

/// Configura este teléfono como kiosco de una obra con el token del dispositivo
/// (el administrador lo obtiene en Dispositivos > Nuevo / Generar token).
class KioscoActivarScreen extends StatefulWidget {
  const KioscoActivarScreen({super.key});

  @override
  State<KioscoActivarScreen> createState() => _KioscoActivarScreenState();
}

class _KioscoActivarScreenState extends State<KioscoActivarScreen> {
  final _servidor = TextEditingController(text: AppConfig.apiUrl);
  final _token = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _servidor.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _activar() async {
    if (_token.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa el token del dispositivo');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await AppConfig.guardarApiUrl(_servidor.text);
      final config = await KioscoService.instancia.activar(_token.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(config.obra != null
            ? 'Kiosco activado en la obra ${config.obra!.nombre}'
            : 'Kiosco activado (sin obra asignada todavía)'),
      ));
      Navigator.pushNamedAndRemoveUntil(context, '/kiosco', (_) => false);
    } on DispositivoNoAutorizado {
      setState(() => _error = 'Token inválido o dispositivo desactivado');
    } on SinConexion {
      setState(() => _error = 'No se pudo conectar con ${AppConfig.apiUrl}. Revisa la dirección y la conexión.');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activar modo kiosco')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Este teléfono quedará fijo en una obra para que los trabajadores marquen '
              'entrada y salida. Funciona sin internet: los marcajes se envían cuando vuelve la señal.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _servidor,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Servidor',
                hintText: 'https://laborlog.miempresa.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _token,
              autocorrect: false,
              enableSuggestions: false,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Token del dispositivo',
                helperText: 'Lo genera el administrador en Dispositivos',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _cargando ? null : _activar,
              icon: _cargando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.phonelink_lock),
              label: const Text('Activar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false),
              child: const Text('Volver al inicio de sesión'),
            ),
          ],
        ),
      ),
    );
  }
}
