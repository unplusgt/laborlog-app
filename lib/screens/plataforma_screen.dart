import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Panel del dueño de LaborLog: alta de empresas clientes y su primer super admin.
/// No muestra datos internos de las empresas, solo conteos.
class PlataformaScreen extends StatefulWidget {
  const PlataformaScreen({super.key});

  @override
  State<PlataformaScreen> createState() => _PlataformaScreenState();
}

class _PlataformaScreenState extends State<PlataformaScreen> {
  List<Map<String, dynamic>> _empresas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final e = await ApiService.getEmpresasPlataforma();
      setState(() => _empresas = e);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _ejecutar(Future<void> Function() accion, {String? exito}) async {
    try {
      await accion();
      await _cargar();
      if (exito != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exito)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  static String _codigoDesde(String nombre) => nombre
      .toLowerCase()
      .replaceAll(RegExp('[áàä]'), 'a')
      .replaceAll(RegExp('[éèë]'), 'e')
      .replaceAll(RegExp('[íìï]'), 'i')
      .replaceAll(RegExp('[óòö]'), 'o')
      .replaceAll(RegExp('[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _nueva() async {
    final nombre = TextEditingController();
    final codigo = TextEditingController();
    final zona = TextEditingController(text: 'America/Guatemala');
    final adminNombre = TextEditingController();
    final adminUsuario = TextEditingController();
    final adminEmail = TextEditingController();
    final adminPassword = TextEditingController();
    var codigoEditado = false;
    String? error;

    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nueva empresa'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nombre,
                    decoration: const InputDecoration(labelText: 'Nombre de la empresa'),
                    onChanged: (v) {
                      if (!codigoEditado) setLocal(() => codigo.text = _codigoDesde(v));
                    },
                  ),
                  TextField(
                    controller: codigo,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Código (para iniciar sesión)',
                      helperText: 'minúsculas, números y guiones; p. ej. constructora-abc',
                    ),
                    onChanged: (_) => codigoEditado = true,
                  ),
                  TextField(controller: zona, decoration: const InputDecoration(labelText: 'Zona horaria')),
                  const SizedBox(height: 16),
                  Text('Super admin de la empresa (dueño / RRHH)', style: Theme.of(ctx).textTheme.titleSmall),
                  TextField(controller: adminNombre, decoration: const InputDecoration(labelText: 'Nombre')),
                  TextField(
                    controller: adminUsuario,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Usuario'),
                  ),
                  TextField(
                    controller: adminEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo (opcional)'),
                  ),
                  TextField(
                    controller: adminPassword,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña inicial',
                      helperText: 'mínimo 8 caracteres; entrégala de forma privada',
                    ),
                  ),
                  if (error != null) Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if ([nombre, codigo, adminNombre, adminUsuario].any((c) => c.text.trim().isEmpty)) {
                  setLocal(() => error = 'Completa nombre, código, y nombre y usuario del super admin');
                  return;
                }
                if (adminPassword.text.length < 8) {
                  setLocal(() => error = 'La contraseña debe tener al menos 8 caracteres');
                  return;
                }
                Navigator.pop(ctx, {
                  'nombre': nombre.text.trim(),
                  'codigo': codigo.text.trim().toLowerCase(),
                  'zona_horaria': zona.text.trim(),
                  'superadmin': {
                    'nombre': adminNombre.text.trim(),
                    'usuario': adminUsuario.text.trim().toLowerCase(),
                    'email': adminEmail.text.trim().isEmpty ? null : adminEmail.text.trim(),
                    'password': adminPassword.text,
                  },
                });
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    if (datos == null) return;
    await _ejecutar(
      () => ApiService.crearEmpresaPlataforma(datos),
      exito: 'Empresa creada. Acceso: empresa "${datos['codigo']}", usuario "${datos['superadmin']['usuario']}".',
    );
  }

  Future<void> _salir() async {
    await AuthService().logout();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LaborLog · Plataforma'),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _salir, icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _cargando ? null : _nueva,
        icon: const Icon(Icons.add_business),
        label: const Text('Nueva empresa'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _empresas.isEmpty
                  ? const Center(child: Text('Aún no hay empresas'))
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: _empresas.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = _empresas[i];
                        final activa = e['activa'] == true;
                        return ListTile(
                          leading: Icon(Icons.business, color: activa ? Colors.indigo : Colors.grey),
                          title: Text(e['nombre'] ?? ''),
                          subtitle: Text(
                            'Código: ${e['codigo']}${activa ? '' : ' · DESACTIVADA'}\n'
                            '${e['usuarios']} usuarios · ${e['trabajadores']} trabajadores · '
                            '${e['obras']} obras · ${e['dispositivos']} teléfonos',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'activa') {
                                _ejecutar(() => ApiService.actualizarEmpresaPlataforma(e['id'], {'activa': !activa}));
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'activa', child: Text(activa ? 'Desactivar' : 'Activar')),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
