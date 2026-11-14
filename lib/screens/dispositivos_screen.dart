import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/dispositivo.dart';
import '../models/obra.dart';
import '../services/api_service.dart';
import '../utils/app_config.dart';

/// Administración de teléfonos kiosco: crearlos, asignarles obra y generar su token.
class DispositivosScreen extends StatefulWidget {
  const DispositivosScreen({super.key});

  @override
  State<DispositivosScreen> createState() => _DispositivosScreenState();
}

class _DispositivosScreenState extends State<DispositivosScreen> {
  List<Dispositivo> _dispositivos = [];
  List<Obra> _obras = [];
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
      final r = await Future.wait([ApiService.getDispositivos(), ApiService.getObras()]);
      setState(() {
        _dispositivos = r[0] as List<Dispositivo>;
        _obras = r[1] as List<Obra>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _cargando = false);
    }
  }

  String _nombreObra(int? id) {
    if (id == null) return 'Sin obra asignada';
    return _obras.where((o) => o.id == id).map((o) => o.nombre).firstOrNull ?? 'Obra #$id';
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    try {
      await accion();
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  Future<void> _nuevo() async {
    final nombre = TextEditingController();
    int? obraId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nuevo dispositivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombre,
                decoration: const InputDecoration(labelText: 'Nombre (p. ej. Samsung obra BARI)'),
              ),
              const SizedBox(height: 12),
              _selectorObra(obraId, (v) => setLocal(() => obraId = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _ejecutar(() async {
      final d = await ApiService.createDispositivo(
        Dispositivo(id: '', nombre: nombre.text.trim(), obraId: obraId),
      );
      if (d.token != null) await _mostrarToken(d);
    });
  }

  Widget _selectorObra(int? valor, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int?>(
      initialValue: valor,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Obra'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Sin obra asignada')),
        ..._obras.map((o) => DropdownMenuItem<int?>(value: o.id, child: Text(o.nombre))),
      ],
      onChanged: onChanged,
    );
  }

  Future<void> _cambiarObra(Dispositivo d) async {
    int? obraId = d.obraId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Obra de ${d.nombre ?? "dispositivo"}'),
          content: _selectorObra(obraId, (v) => setLocal(() => obraId = v)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _ejecutar(() => ApiService.updateDispositivo(d.id, {'obra_id': obraId}));
    }
  }

  Future<void> _rotarToken(Dispositivo d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generar token nuevo'),
        content: const Text(
          'El token actual dejará de funcionar y habrá que ingresar el nuevo en el teléfono. '
          'Los marcajes que el teléfono tenga guardados se enviarán al activarlo de nuevo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generar')),
        ],
      ),
    );
    if (ok != true) return;
    await _ejecutar(() async {
      final nuevo = await ApiService.rotarTokenDispositivo(d.id);
      await _mostrarToken(nuevo);
    });
  }

  Future<void> _mostrarToken(Dispositivo d) {
    final token = d.token!;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Token del dispositivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingrésalo en el teléfono en "Usar este teléfono como kiosco de obra". '
              'Solo se muestra esta vez.',
            ),
            const SizedBox(height: 12),
            Text('Servidor: ${AppConfig.apiUrl}'),
            const SizedBox(height: 8),
            SelectableText(token, style: const TextStyle(fontFamily: 'monospace', fontSize: 16)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: token));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Token copiado')));
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Listo')),
        ],
      ),
    );
  }

  static String _fecha(DateTime? t) {
    if (t == null) return 'nunca';
    final l = t.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(l.day)}/${dos(l.month)}/${l.year} ${dos(l.hour)}:${dos(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos (kiosco)'),
        actions: [IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _cargando ? null : _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _dispositivos.isEmpty
                  ? const Center(child: Text('No hay dispositivos registrados'))
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: _dispositivos.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final d = _dispositivos[i];
                        return ListTile(
                          leading: Icon(Icons.phone_android,
                              color: d.activo ? Colors.teal : Colors.grey),
                          title: Text(d.nombre ?? 'Sin nombre'),
                          subtitle: Text('${_nombreObra(d.obraId)}\n'
                              'Última conexión: ${_fecha(d.lastSync)}'
                              '${d.activo ? '' : ' · DESACTIVADO'}'),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              switch (v) {
                                case 'obra':
                                  _cambiarObra(d);
                                case 'token':
                                  _rotarToken(d);
                                case 'activo':
                                  _ejecutar(() =>
                                      ApiService.updateDispositivo(d.id, {'activo': !d.activo}));
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'obra', child: Text('Cambiar obra')),
                              const PopupMenuItem(value: 'token', child: Text('Generar token nuevo')),
                              PopupMenuItem(
                                value: 'activo',
                                child: Text(d.activo ? 'Desactivar' : 'Activar'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
