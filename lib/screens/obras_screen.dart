import 'package:flutter/material.dart';
import '../models/obra.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

class ObrasScreen extends StatefulWidget {
  @override
  _ObrasScreenState createState() => _ObrasScreenState();
}

class _ObrasScreenState extends State<ObrasScreen> {
  List<Obra> _obras = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadObras();
  }

  Future<void> _loadObras() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      
      final obras = await ApiService.getObras();
      setState(() {
        _obras = obras;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar obras: $e';
        _loading = false;
      });
    }
  }

  void _showAddDialog() {
    final nombreController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final radioController = TextEditingController();
    
    bool _gettingLocation = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Agregar Obra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre de la obra',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                
                // Sección de ubicación
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ubicación',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: _gettingLocation ? null : () async {
                              setState(() {
                                _gettingLocation = true;
                              });
                              
                              try {
                                final position = await LocationService.getCurrentPosition();
                                if (position != null) {
                                  latController.text = position['latitude']!.toStringAsFixed(6);
                                  lngController.text = position['longitude']!.toStringAsFixed(6);
                                  radioController.text = '50'; // Radio por defecto
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('📍 Ubicación capturada exitosamente'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ No se pudo obtener la ubicación'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } finally {
                                setState(() {
                                  _gettingLocation = false;
                                });
                              }
                            },
                            icon: _gettingLocation 
                                ? SizedBox(
                                    width: 16, 
                                    height: 16, 
                                    child: CircularProgressIndicator(strokeWidth: 2)
                                  )
                                : Icon(Icons.my_location),
                            label: Text(_gettingLocation ? 'Obteniendo...' : 'Capturar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: latController,
                        decoration: InputDecoration(
                          labelText: 'Latitud',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 12),
                      TextField(
                        controller: lngController,
                        decoration: InputDecoration(
                          labelText: 'Longitud',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 16),
                TextField(
                  controller: radioController,
                  decoration: InputDecoration(
                    labelText: 'Radio en metros',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.radio_button_unchecked),
                    helperText: 'Área de cobertura para marcajes',
                  ),
                  keyboardType: TextInputType.number,
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
                    SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }
                
                try {
                  await ApiService.createObra(Obra(
                    id: 0, // será asignado por el backend
                    nombre: nombreController.text.trim(),
                    lat: latController.text.trim().isEmpty ? null : latController.text.trim(),
                    lng: lngController.text.trim().isEmpty ? null : lngController.text.trim(),
                    radioMetros: radioController.text.trim().isEmpty ? null : int.tryParse(radioController.text.trim()),
                  ));
                  
                  Navigator.pop(context);
                  _loadObras(); // Recargar lista
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Obra agregada exitosamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Obras'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          if (AuthService.puedeGestionar)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: _showAddDialog,
              tooltip: 'Agregar obra',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadObras,
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
                        onPressed: _loadObras,
                        child: Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _obras.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No hay obras registradas',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 16),
                          if (AuthService.puedeGestionar)
                            ElevatedButton(
                              onPressed: _showAddDialog,
                              child: Text('Agregar primera obra'),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(8),
                      itemCount: _obras.length,
                      itemBuilder: (context, index) {
                        final obra = _obras[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.purple,
                              child: Icon(
                                Icons.business, 
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              obra.nombre,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (obra.lat != null && obra.lng != null) ...[
                                  Text(
                                    '📍 ${double.parse(obra.lat!).toStringAsFixed(4)}, ${double.parse(obra.lng!).toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  if (obra.radioMetros != null)
                                    Text(
                                      '📏 Radio: ${obra.radioMetros}m de cobertura',
                                      style: TextStyle(color: Colors.orange.shade700),
                                    ),
                                ] else
                                  Text(
                                    '❌ Sin ubicación GPS',
                                    style: TextStyle(
                                      color: Colors.orange.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                SizedBox(height: 4),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Text(
                                    '🟢 Disponible',
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: !AuthService.puedeGestionar ? null : PopupMenuButton(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editObra(obra);
                                }
                              },
                              itemBuilder: (context) => [
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
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  void _editObra(Obra obra) async {
    final nombreController = TextEditingController(text: obra.nombre);
    final latController = TextEditingController(text: obra.lat);
    final lngController = TextEditingController(text: obra.lng);
    final radioController = TextEditingController(
      text: obra.radioMetros?.toString() ?? '100'
    );

    bool gettingLocation = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Editar Obra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: InputDecoration(labelText: 'Nombre'),
                ),
                SizedBox(height: 16),
                // Sección de ubicación
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ubicación',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: gettingLocation ? null : () async {
                              setState(() {
                                gettingLocation = true;
                              });
                              
                              try {
                                final position = await LocationService.getCurrentPosition();
                                if (position != null) {
                                  latController.text = position['latitude']!.toStringAsFixed(6);
                                  lngController.text = position['longitude']!.toStringAsFixed(6);
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('📍 Ubicación capturada exitosamente'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ No se pudo obtener la ubicación'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } finally {
                                setState(() {
                                  gettingLocation = false;
                                });
                              }
                            },
                            icon: gettingLocation 
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)
                                )
                              : Icon(Icons.my_location),
                            label: Text(gettingLocation ? 'Obteniendo...' : 'Capturar ubicación'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gettingLocation ? Colors.grey : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latController,
                              decoration: InputDecoration(
                                labelText: 'Latitud',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lngController,
                              decoration: InputDecoration(
                                labelText: 'Longitud',
                                isDense: true,
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: radioController,
                        decoration: InputDecoration(
                          labelText: 'Radio de validación (metros)',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
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
                  final obraActualizada = Obra(
                    id: obra.id,
                    nombre: nombreController.text.trim(),
                    lat: latController.text.trim().isEmpty ? null : latController.text.trim(),
                    lng: lngController.text.trim().isEmpty ? null : lngController.text.trim(),
                    radioMetros: int.tryParse(radioController.text.trim()) ?? 100,
                  );

                  await ApiService.updateObra(obra.id, obraActualizada);
                  Navigator.pop(context);
                  _loadObras();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ Obra actualizada exitosamente')),
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
      ),
    );
  }
}