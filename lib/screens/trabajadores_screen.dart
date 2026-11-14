import 'package:flutter/material.dart';
import '../models/trabajador.dart';
import '../services/api_service.dart';
import 'registro_rostro_screen.dart';

class TrabajadoresScreen extends StatefulWidget {
  @override
  _TrabajadoresScreenState createState() => _TrabajadoresScreenState();
}

class _TrabajadoresScreenState extends State<TrabajadoresScreen> {
  List<Trabajador> _trabajadores = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrabajadores();
  }

  Future<void> _loadTrabajadores() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      
      final trabajadores = await ApiService.getTrabajadores();
      setState(() {
        _trabajadores = trabajadores;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar trabajadores: $e';
        _loading = false;
      });
    }
  }

  void _showAddDialog() {
    final nombreController = TextEditingController();
    final dniController = TextEditingController();
    final telefonoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Agregar Trabajador'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: dniController,
                decoration: InputDecoration(
                  labelText: 'DNI',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: telefonoController,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.trim().isEmpty) return;
              
              try {
                await ApiService.createTrabajador(Trabajador(
                  id: '', // será asignado por el backend
                  nombre: nombreController.text.trim(),
                  dni: dniController.text.trim(),
                  telefono: telefonoController.text.trim(),
                  activo: true,
                ));
                
                Navigator.pop(context);
                _loadTrabajadores(); // Recargar lista
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Trabajador agregado exitosamente')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text('Agregar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trabajadores'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddDialog,
            tooltip: 'Agregar trabajador',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTrabajadores,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.red)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTrabajadores,
                        child: Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _trabajadores.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No hay trabajadores registrados',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _showAddDialog,
                            child: Text('Agregar primer trabajador'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(8),
                      itemCount: _trabajadores.length,
                      itemBuilder: (context, index) {
                        final trabajador = _trabajadores[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: trabajador.activo ? Colors.green : Colors.grey,
                              child: Icon(
                                Icons.person, 
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              trabajador.nombre,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (trabajador.dni?.isNotEmpty == true)
                                  Text('📄 DNI: ${trabajador.dni}'),
                                if (trabajador.telefono?.isNotEmpty == true)
                                  Text('📞 ${trabajador.telefono}'),
                                Text(
                                  trabajador.rostroRegistrado ? '🙂 Rostro registrado' : '⚪ Sin rostro',
                                  style: TextStyle(color: trabajador.rostroRegistrado ? Colors.green : Colors.grey),
                                ),
                                Text(
                                  trabajador.activo ? '🟢 Activo' : '🔴 Inactivo',
                                  style: TextStyle(
                                    color: trabajador.activo ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editTrabajador(trabajador);
                                } else if (value == 'toggle') {
                                  _toggleTrabajador(trabajador);
                                } else if (value == 'rostro') {
                                  _registrarRostro(trabajador);
                                } else if (value == 'borrar_rostro') {
                                  _borrarRostro(trabajador);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'rostro',
                                  child: Row(
                                    children: [
                                      Icon(Icons.face, size: 20),
                                      SizedBox(width: 8),
                                      Text(trabajador.rostroRegistrado ? 'Reemplazar rostro' : 'Registrar rostro'),
                                    ],
                                  ),
                                ),
                                if (trabajador.rostroRegistrado)
                                  PopupMenuItem(
                                    value: 'borrar_rostro',
                                    child: Row(
                                      children: [
                                        Icon(Icons.no_photography, size: 20),
                                        SizedBox(width: 8),
                                        Text('Borrar rostro'),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Editar'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(
                                    children: [
                                      Icon(
                                        trabajador.activo ? Icons.block : Icons.check_circle,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(trabajador.activo ? 'Desactivar' : 'Activar'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Future<void> _registrarRostro(Trabajador trabajador) async {
    final ok = await RegistroRostroScreen.abrir(
      context,
      trabajadorId: trabajador.id,
      nombre: trabajador.nombre,
      yaRegistrado: trabajador.rostroRegistrado,
    );
    if (ok) _loadTrabajadores();
  }

  Future<void> _borrarRostro(Trabajador trabajador) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Borrar rostro'),
        content: Text('Se eliminan la huella facial y la foto de referencia de ${trabajador.nombre}. '
            'No podrá marcar con el rostro hasta registrarlo de nuevo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Borrar')),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ApiService.borrarRostro(trabajador.id);
      _loadTrabajadores();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  void _editTrabajador(Trabajador trabajador) async {
    final nombreController = TextEditingController(text: trabajador.nombre);
    final dniController = TextEditingController(text: trabajador.dni);
    final telefonoController = TextEditingController(text: trabajador.telefono);
    final codigoController = TextEditingController(text: trabajador.codigoEmpresa);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Trabajador'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: dniController,
                decoration: InputDecoration(labelText: 'DNI'),
              ),
              TextField(
                controller: telefonoController,
                decoration: InputDecoration(labelText: 'Teléfono'),
              ),
              TextField(
                controller: codigoController,
                decoration: InputDecoration(labelText: 'Código Empresa'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: El nombre es obligatorio')),
                );
                return;
              }

              try {
                final trabajadorActualizado = Trabajador(
                  id: trabajador.id,
                  nombre: nombreController.text.trim(),
                  dni: dniController.text.trim().isEmpty ? null : dniController.text.trim(),
                  telefono: telefonoController.text.trim().isEmpty ? null : telefonoController.text.trim(),
                  codigoEmpresa: codigoController.text.trim().isEmpty ? null : codigoController.text.trim(),
                  fechaRegistro: trabajador.fechaRegistro,
                  fotoRegistroPath: trabajador.fotoRegistroPath,
                  activo: trabajador.activo,
                );

                await ApiService.updateTrabajador(trabajador.id, trabajadorActualizado);
                Navigator.pop(context);
                _loadTrabajadores();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ Trabajador actualizado exitosamente')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text('Actualizar'),
          ),
        ],
      ),
    );
  }

  void _toggleTrabajador(Trabajador trabajador) async {
    try {
      final trabajadorActualizado = Trabajador(
        id: trabajador.id,
        nombre: trabajador.nombre,
        dni: trabajador.dni,
        telefono: trabajador.telefono,
        codigoEmpresa: trabajador.codigoEmpresa,
        fechaRegistro: trabajador.fechaRegistro,
        fotoRegistroPath: trabajador.fotoRegistroPath,
        activo: !trabajador.activo,
      );

      await ApiService.updateTrabajador(trabajador.id, trabajadorActualizado);
      _loadTrabajadores();
      
      final statusText = trabajadorActualizado.activo ? 'activado' : 'desactivado';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Trabajador $statusText exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}