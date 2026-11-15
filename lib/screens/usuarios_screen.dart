import 'package:flutter/material.dart';

import '../models/obra.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Usuarios de la empresa. El super admin crea jefes, supervisores y otros super
/// admins; el jefe solo supervisores. A cada supervisor se le asignan sus obras.
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  List<UsuarioAdmin> _usuarios = [];
  List<Obra> _obras = [];
  bool _cargando = true;
  String? _error;

  List<String> get _rolesAsignables => AuthService.isSuperadmin
      ? const [Roles.supervisor, Roles.jefe, Roles.superadmin]
      : const [Roles.supervisor];

  bool _puedeEditar(UsuarioAdmin u) => _rolesAsignables.contains(u.rol);

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
      final r = await Future.wait([ApiService.getUsuarios(), ApiService.getObras()]);
      setState(() {
        _usuarios = r[0] as List<UsuarioAdmin>;
        _obras = r[1] as List<Obra>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _nombresObras(List<int> ids) {
    if (ids.isEmpty) return 'sin obras asignadas';
    return ids.map((id) => _obras.where((o) => o.id == id).map((o) => o.nombre).firstOrNull ?? '#$id').join(', ');
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    try {
      await accion();
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _formulario({UsuarioAdmin? existente}) async {
    final nombre = TextEditingController(text: existente?.nombre);
    final usuario = TextEditingController(text: existente?.usuario);
    final email = TextEditingController(text: existente?.email);
    final password = TextEditingController();
    var rol = existente?.rol ?? Roles.supervisor;
    final obras = {...?existente?.obras};
    String? error;

    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existente == null ? 'Nuevo usuario' : 'Editar ${existente.nombre}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre completo')),
                  TextField(
                    controller: usuario,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Usuario (para iniciar sesión)',
                      helperText: 'minúsculas, números, punto o guion; p. ej. juan.perez',
                    ),
                  ),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo (opcional)'),
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: existente == null ? 'Contraseña' : 'Nueva contraseña (opcional)',
                      helperText: 'mínimo 8 caracteres',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: rol,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: [
                      for (final r in _rolesAsignables) DropdownMenuItem(value: r, child: Text(Roles.nombre(r))),
                    ],
                    onChanged: existente?.id == AuthService.currentUser?.id
                        ? null
                        : (v) => setLocal(() => rol = v ?? rol),
                  ),
                  if (rol == Roles.supervisor) ...[
                    const SizedBox(height: 12),
                    const Align(alignment: Alignment.centerLeft, child: Text('Obras asignadas')),
                    if (_obras.isEmpty) const Text('No hay obras creadas', style: TextStyle(color: Colors.grey)),
                    for (final o in _obras)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: obras.contains(o.id),
                        title: Text(o.nombre),
                        onChanged: (v) => setLocal(() => v == true ? obras.add(o.id) : obras.remove(o.id)),
                      ),
                  ],
                  if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final u = usuario.text.trim().toLowerCase();
                if (nombre.text.trim().isEmpty || u.isEmpty) {
                  setLocal(() => error = 'Nombre y usuario son obligatorios');
                  return;
                }
                if (existente == null && password.text.length < 8) {
                  setLocal(() => error = 'La contraseña debe tener al menos 8 caracteres');
                  return;
                }
                Navigator.pop(ctx, {
                  'nombre': nombre.text.trim(),
                  'usuario': u,
                  'email': email.text.trim().isEmpty ? null : email.text.trim(),
                  if (password.text.isNotEmpty) 'password': password.text,
                  if (existente == null || existente.rol != rol) 'rol': rol,
                  if (rol == Roles.supervisor) 'obras': obras.toList(),
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (datos == null) return;
    await _ejecutar(() async {
      if (existente == null) {
        await ApiService.crearUsuario(datos);
      } else {
        await ApiService.actualizarUsuario(existente.id, datos);
      }
    });
  }

  Future<void> _eliminar(UsuarioAdmin u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a ${u.nombre} (${u.usuario})? Si solo quieres impedir que entre, desactívalo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) await _ejecutar(() => ApiService.eliminarUsuario(u.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _cargando ? null : () => _formulario(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _usuarios.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = _usuarios[i];
                    final yo = u.id == AuthService.currentUser?.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: u.activo ? Colors.indigo.shade100 : Colors.grey.shade300,
                        child: Text(u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?'),
                      ),
                      title: Text('${u.nombre}${yo ? ' (tú)' : ''}'),
                      subtitle: Text([
                        '${Roles.nombre(u.rol)} · ${u.usuario}${u.email != null ? ' · ${u.email}' : ''}',
                        if (u.rol == Roles.supervisor) 'Obras: ${_nombresObras(u.obras)}',
                        if (!u.activo) 'DESACTIVADO',
                      ].join('\n')),
                      isThreeLine: u.rol == Roles.supervisor || !u.activo,
                      trailing: !_puedeEditar(u)
                          ? null
                          : PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'editar':
                                    _formulario(existente: u);
                                  case 'activo':
                                    _ejecutar(() => ApiService.actualizarUsuario(u.id, {'activo': !u.activo}));
                                  case 'eliminar':
                                    _eliminar(u);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                                if (!yo) PopupMenuItem(value: 'activo', child: Text(u.activo ? 'Desactivar' : 'Activar')),
                                if (!yo) const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                              ],
                            ),
                    );
                  },
                ),
    );
  }
}
