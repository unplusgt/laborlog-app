import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../rostro/comparacion.dart';
import '../rostro/escaner_rostro.dart';
import '../services/api_service.dart';

/// Registro del rostro de un trabajador. Lo hace un supervisor o administrador con
/// sesión iniciada, en el celular, y requiere la autorización del trabajador.
class RegistroRostroScreen extends StatefulWidget {
  final String trabajadorId;
  final String nombre;
  final bool yaRegistrado;

  const RegistroRostroScreen({
    super.key,
    required this.trabajadorId,
    required this.nombre,
    this.yaRegistrado = false,
  });

  /// Devuelve true si se registró.
  static Future<bool> abrir(BuildContext context, {required String trabajadorId, required String nombre, bool yaRegistrado = false}) async {
    final r = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegistroRostroScreen(trabajadorId: trabajadorId, nombre: nombre, yaRegistrado: yaRegistrado),
      ),
    );
    return r == true;
  }

  @override
  State<RegistroRostroScreen> createState() => _RegistroRostroScreenState();
}

class _RegistroRostroScreenState extends State<RegistroRostroScreen> {
  static const _capturas = 3;

  bool _autoriza = false;
  bool _enviando = false;
  String? _error;

  Future<void> _capturar() async {
    setState(() => _error = null);
    final capturas = await EscanerRostroScreen.abrir(
      context,
      titulo: 'Rostro de ${widget.nombre}',
      capturas: _capturas,
    );
    if (capturas == null || capturas.isEmpty || !mounted) return;

    // Las capturas deben ser de la misma persona entre sí
    final huella = promediar([for (final c in capturas) c.huella]);
    for (final c in capturas) {
      if (coseno(huella, c.huella) < 0.75) {
        setState(() => _error = 'Las capturas no son consistentes (¿cambió la persona o la luz?). Intenta de nuevo.');
        return;
      }
    }

    setState(() => _enviando = true);
    try {
      await ApiService.registrarRostro(
        widget.trabajadorId,
        huellaABase64(huella),
        base64Encode(capturas.first.jpeg),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rostro de ${widget.nombre} registrado')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar rostro')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.nombre, style: Theme.of(context).textTheme.headlineSmall),
            if (widget.yaRegistrado)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Ya tiene un rostro registrado: se reemplazará.', style: TextStyle(color: Colors.orange)),
              ),
            const SizedBox(height: 16),
            if (kIsWeb)
              const Text(
                'El registro de rostro se hace desde la app del celular (necesita la cámara).',
                style: TextStyle(color: Colors.red),
              )
            else ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Autorización del trabajador\n\n'
                    'Se guardará una foto de su rostro y una huella facial (un código numérico '
                    'calculado a partir de la foto) para identificarlo al marcar entrada y salida. '
                    'Cada marcaje también guardará una foto pequeña como evidencia. Estos datos '
                    'solo se usan para el control de asistencia y se pueden borrar cuando lo pida '
                    'o deje de trabajar en la empresa.',
                  ),
                ),
              ),
              CheckboxListTile(
                value: _autoriza,
                onChanged: _enviando ? null : (v) => setState(() => _autoriza = v ?? false),
                title: Text('${widget.nombre} leyó (o se le leyó) lo anterior y autoriza el uso de su rostro'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              const Text(
                'Consejos: buena luz de frente, sin lentes oscuros, gorra ni casco; la cara '
                'completa dentro del óvalo. La cámara pedirá parpadear o girar la cabeza.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: !_autoriza || _enviando ? null : _capturar,
                  icon: _enviando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.face),
                  label: Text(_enviando ? 'Guardando…' : 'Abrir cámara'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
