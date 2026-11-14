import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../models/trabajador.dart';
import '../models/obra.dart';
import '../models/attendance.dart';
import '../models/dispositivo.dart';
import 'dart:math';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<Trabajador> _trabajadores = [];
  List<Obra> _obras = [];
  List<Dispositivo> _dispositivos = [];
  
  // Selección múltiple de trabajadores
  List<Trabajador> _trabajadoresEnCola = [];
  Trabajador? _selectedTrabajador; // Para compatibilidad con funciones existentes
  final TextEditingController _trabajadorSearchController = TextEditingController();
  List<Trabajador> _trabajadoresFiltrados = [];
  bool _showTrabajadorList = false;
  
  Obra? _selectedObra;
  String _tipoMarcaje = 'entrada';
  
  bool _loading = false;
  bool _dataLoaded = false;
  String? _error;

  // Control GPS y marcajes - optimizado para uso múltiple
  Map<String, double>? _currentLocation;
  DateTime? _locationTimestamp;
  double? _distanceToObra;
  bool _gettingLocation = false;
  String? _lastTipoMarcaje;
  String? _locationError;
  
  // Control de marcajes masivos
  bool _processingBatch = false;
  int _currentWorkerIndex = 0;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _trabajadorSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final futures = await Future.wait([
        ApiService.getTrabajadores(),
        ApiService.getObras(),
        ApiService.getDispositivos(),
      ]);
      
      setState(() {
        _trabajadores = futures[0] as List<Trabajador>;
        _trabajadoresFiltrados = _trabajadores; // Inicializar lista filtrada
        _obras = futures[1] as List<Obra>;
        _dispositivos = futures[2] as List<Dispositivo>;
        _dataLoaded = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Buscar trabajadores por nombre o DNI
  void _filterTrabajadores(String query) {
    setState(() {
      if (query.isEmpty) {
        _trabajadoresFiltrados = _trabajadores;
      } else {
        _trabajadoresFiltrados = _trabajadores.where((trabajador) {
          final nombreMatch = trabajador.nombre.toLowerCase().contains(query.toLowerCase());
          final dniMatch = trabajador.dni?.toLowerCase().contains(query.toLowerCase()) ?? false;
          return nombreMatch || dniMatch;
        }).toList();
      }
    });
  }

  // Agregar trabajador a la cola
  void _addTrabajadorToCola(Trabajador trabajador) {
    if (!_trabajadoresEnCola.any((t) => t.id == trabajador.id)) {
      setState(() {
        _trabajadoresEnCola.add(trabajador);
        _trabajadorSearchController.clear();
        _trabajadoresFiltrados = _trabajadores;
        _showTrabajadorList = false;
      });
      _showSnackBar('➕ ${trabajador.nombre} agregado a la cola');
    } else {
      _showSnackBar('⚠️ ${trabajador.nombre} ya está en la cola');
    }
  }

  // Remover trabajador de la cola
  void _removeTrabajadorFromCola(Trabajador trabajador) {
    setState(() {
      _trabajadoresEnCola.removeWhere((t) => t.id == trabajador.id);
    });
    _showSnackBar('➖ ${trabajador.nombre} removido de la cola');
  }

  // Verificar si la ubicación GPS es reciente (menos de 10 minutos)
  bool _isLocationRecent() {
    if (_currentLocation == null || _locationTimestamp == null) return false;
    final now = DateTime.now();
    final difference = now.difference(_locationTimestamp!);
    return difference.inMinutes < 10;
  }

  // Obtener ubicación actual del dispositivo optimizada
  Future<void> _getCurrentLocation() async {
    // Si la ubicación es reciente (menos de 10 min), reutilizarla
    if (_isLocationRecent()) {
      _showSnackBar('📍 Reutilizando ubicación reciente');
      if (_selectedObra != null) {
        _calculateDistanceToObra();
      }
      return;
    }

    setState(() {
      _gettingLocation = true;
      _locationError = null;
    });

    try {
      final location = await LocationService.getCurrentPosition();
      setState(() {
        _currentLocation = location;
        _locationTimestamp = DateTime.now();
        _gettingLocation = false;
      });
      
      if (_selectedObra != null) {
        _calculateDistanceToObra();
      }
      
      _showSnackBar('✅ Ubicación GPS actualizada');
    } catch (e) {
      setState(() {
        _locationError = e.toString();
        _gettingLocation = false;
      });
    }
  }

  // Calcular distancia a la obra seleccionada
  void _calculateDistanceToObra() {
    if (_currentLocation == null || _selectedObra == null) return;
    
    if (_selectedObra!.lat != null && _selectedObra!.lng != null) {
      try {
        final obraLat = double.parse(_selectedObra!.lat!);
        final obraLng = double.parse(_selectedObra!.lng!);
        final distance = _calculateDistance(
          _currentLocation!['latitude']!,
          _currentLocation!['longitude']!,
          obraLat,
          obraLng,
        );
        
        setState(() {
          _distanceToObra = distance;
        });
      } catch (e) {
        debugPrint('Error calculando distancia: $e');
      }
    }
  }

  // Calcular distancia entre dos puntos GPS (fórmula de Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Radio de la Tierra en metros
    
    final double lat1Rad = lat1 * (pi / 180);
    final double lat2Rad = lat2 * (pi / 180);
    final double deltaLatRad = (lat2 - lat1) * (pi / 180);
    final double deltaLonRad = (lon2 - lon1) * (pi / 180);
    
    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLonRad / 2) * sin(deltaLonRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  // Obtener el último marcaje del trabajador del día actual
  Future<void> _getLastMarcajeToday({Trabajador? trabajador}) async {
    final targetTrabajador = trabajador ?? _selectedTrabajador;
    if (targetTrabajador == null) return;

    try {
      debugPrint('🔍 Consultando marcajes del trabajador: ${targetTrabajador.nombre}');
      final marcajes = await ApiService.getMarcajes();
      debugPrint('📊 Total de marcajes obtenidos: ${marcajes.length}');
      
      // Misma regla que el backend: se mira el turno actual (últimas 20 h), no el día
      // calendario, para que un turno nocturno (22:00 → 06:00) pueda marcar su salida.
      final now = DateTime.now();
      final inicioVentana = now.subtract(Duration(hours: 20));

      final marcajesHoy = marcajes.where((marcaje) {
        final marcajeTime = marcaje.timestampLocal;
        final enVentana = marcajeTime.isAfter(inicioVentana) && !marcajeTime.isAfter(now);
        final isSameWorker = marcaje.trabajadorId == targetTrabajador.id;

        return isSameWorker && enVentana;
      }).toList();

      debugPrint('🎯 Marcajes del trabajador hoy: ${marcajesHoy.length}');
      
      // Ordenar por hora y obtener el último
      if (marcajesHoy.isNotEmpty) {
        marcajesHoy.sort((a, b) => b.timestampLocal.compareTo(a.timestampLocal));
        final lastMarcaje = marcajesHoy.first;
        
        debugPrint('⏰ Último marcaje: ${lastMarcaje.tipo.toUpperCase()} a las ${lastMarcaje.timestampLocal.toString().substring(11, 19)}');
        
        setState(() {
          _lastTipoMarcaje = lastMarcaje.tipo;
          // Ajustar el tipo de marcaje sugerido
          _tipoMarcaje = lastMarcaje.tipo == 'entrada' ? 'salida' : 'entrada';
        });
      } else {
        debugPrint('🆕 No hay marcajes previos hoy - primer marcaje será ENTRADA');
        setState(() {
          _lastTipoMarcaje = null;
          _tipoMarcaje = 'entrada'; // Primera marcaje del día
        });
      }
    } catch (e) {
      debugPrint('❌ Error obteniendo último marcaje: $e');
      setState(() {
        _lastTipoMarcaje = null;
        _tipoMarcaje = 'entrada';
      });
    }
  }

  // Validar si se puede realizar el marcaje
  bool _canMarkAttendance([String? tipo]) {
    // Debe tener ubicación actual
    if (_currentLocation == null) return false;
    
    // Debe estar dentro del radio de la obra
    if (_distanceToObra != null && _selectedObra?.radioMetros != null) {
      if (_distanceToObra! > _selectedObra!.radioMetros!) {
        return false;
      }
    }

    // Si se especifica un tipo, validar la lógica de entrada/salida
    if (tipo != null && _lastTipoMarcaje != null) {
      if (_lastTipoMarcaje == tipo) {
        return false; // No puede marcar el mismo tipo dos veces seguidas
      }
    } else if (tipo != null && _lastTipoMarcaje == null) {
      // Si no hay marcaje previo, solo puede marcar entrada
      return tipo == 'entrada';
    }
    
    return true;
  }

  // Registrar asistencia individual (modificado para no salir)
  Future<void> _registrarAsistencia({Trabajador? trabajador}) async {
    final targetTrabajador = trabajador ?? _selectedTrabajador;
    
    if (targetTrabajador == null || _selectedObra == null) {
      _showSnackBar('Selecciona trabajador y obra');
      return;
    }

    // 🚨 VALIDACIÓN GPS: Verificar que la obra tenga coordenadas
    if (_selectedObra!.lat == null || _selectedObra!.lng == null ||
        _selectedObra!.lat!.trim().isEmpty || _selectedObra!.lng!.trim().isEmpty) {
      _showSnackBar('❌ La obra "${_selectedObra!.nombre}" no tiene ubicación GPS configurada. Edita la obra primero.');
      return;
    }

    // Validar que las coordenadas sean números válidos
    try {
      double.parse(_selectedObra!.lat!);
      double.parse(_selectedObra!.lng!);
    } catch (e) {
      _showSnackBar('❌ Las coordenadas GPS de la obra "${_selectedObra!.nombre}" no son válidas. Edita la obra primero.');
      return;
    }

    if (_dispositivos.isEmpty) {
      _showSnackBar('No hay dispositivos disponibles');
      return;
    }

    // Validar que tenga ubicación actual
    if (_currentLocation == null) {
      _showSnackBar('⚠️ No se ha obtenido tu ubicación. Presiona "Obtener Ubicación"');
      return;
    }

    // Obtener último marcaje del trabajador para validación
    await _getLastMarcajeToday(trabajador: targetTrabajador);

    // Validar el tipo de marcaje (entrada/salida duplicada)
    if (!_canMarkAttendance(_tipoMarcaje)) {
      if (_lastTipoMarcaje == _tipoMarcaje) {
        _showSnackBar('❌ Ya marcó ${_tipoMarcaje.toUpperCase()} hoy. Debe marcar ${_lastTipoMarcaje == "entrada" ? "SALIDA" : "ENTRADA"}');
      } else {
        _showSnackBar('❌ ${_getAttendanceMessage()}');
      }
      return;
    }

    // Validar distancia a la obra 
    if (_distanceToObra != null && _selectedObra?.radioMetros != null && _distanceToObra! > _selectedObra!.radioMetros!) {
      final distanceText = _distanceToObra?.toStringAsFixed(0) ?? 'N/A';
      final radioText = _selectedObra?.radioMetros?.toString() ?? 'N/A';
      _showSnackBar('❌ Está a ${distanceText}m de la obra. Máximo permitido: ${radioText}m');
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // Crear marcaje con coordenadas GPS reales
      final marcaje = Marcaje(
        id: '', // Se asignará en el backend
        trabajadorId: targetTrabajador.id,
        obraId: _selectedObra!.id,
        tipo: _tipoMarcaje,
        timestampLocal: DateTime.now(),
        origen: _dispositivos.first.id,
        lat: _currentLocation!['latitude']!.toStringAsFixed(6),
        lng: _currentLocation!['longitude']!.toStringAsFixed(6),
      );

      final resultado = await ApiService.createMarcaje(marcaje);
      debugPrint('✅ Marcaje registrado exitosamente');
      debugPrint('📋 Detalles: ${targetTrabajador.nombre} - ${_tipoMarcaje.toUpperCase()} en ${_selectedObra!.nombre}');
      debugPrint('📍 GPS: ${_currentLocation!["latitude"]!.toStringAsFixed(6)}, ${_currentLocation!["longitude"]!.toStringAsFixed(6)}');
      debugPrint('🆔 ID: ${resultado.id}, Timestamp: ${resultado.timestampLocal}');
      
      // Actualizar el último marcaje localmente
      setState(() {
        _lastTipoMarcaje = _tipoMarcaje;
        _tipoMarcaje = _tipoMarcaje == 'entrada' ? 'salida' : 'entrada';
        _lastMessage = '✅ ${targetTrabajador.nombre}: ${_lastTipoMarcaje!.toUpperCase()} registrada';
      });
      
      _showSnackBar('✅ ${targetTrabajador.nombre}: Asistencia registrada exitosamente');
      
      // NO SALIR DE LA PANTALLA - Solo limpiar trabajador actual
      setState(() {
        _selectedTrabajador = null;
      });
      
    } catch (e) {
      _showSnackBar('Error al registrar: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Procesar toda la cola de trabajadores
  Future<void> _processBatchMarkings() async {
    if (_trabajadoresEnCola.isEmpty) {
      _showSnackBar('⚠️ No hay trabajadores en la cola');
      return;
    }

    if (_selectedObra == null) {
      _showSnackBar('⚠️ Selecciona una obra primero');
      return;
    }

    // 🚨 VALIDACIÓN GPS: Verificar que la obra tenga coordenadas para procesamiento masivo
    if (_selectedObra!.lat == null || _selectedObra!.lng == null ||
        _selectedObra!.lat!.trim().isEmpty || _selectedObra!.lng!.trim().isEmpty) {
      _showSnackBar('❌ La obra "${_selectedObra!.nombre}" no tiene ubicación GPS. No se puede procesar marcajes masivos sin GPS.');
      return;
    }

    try {
      double.parse(_selectedObra!.lat!);
      double.parse(_selectedObra!.lng!);
    } catch (e) {
      _showSnackBar('❌ Las coordenadas GPS de la obra "${_selectedObra!.nombre}" no son válidas.');
      return;
    }

    if (_currentLocation == null) {
      _showSnackBar('⚠️ Obtener ubicación GPS primero');
      return;
    }

    setState(() {
      _processingBatch = true;
      _currentWorkerIndex = 0;
    });

    int sucessCount = 0;
    int errorCount = 0;

    for (int i = 0; i < _trabajadoresEnCola.length; i++) {
      setState(() {
        _currentWorkerIndex = i;
      });

      try {
        await _registrarAsistencia(trabajador: _trabajadoresEnCola[i]);
        sucessCount++;
        
        // Pequeño delay para estabilidad
        await Future.delayed(Duration(milliseconds: 500));
      } catch (e) {
        errorCount++;
        debugPrint('Error con ${_trabajadoresEnCola[i].nombre}: $e');
      }
    }

    setState(() {
      _processingBatch = false;
      _trabajadoresEnCola.clear(); // Limpiar cola después de procesar
      _currentWorkerIndex = 0;
    });

    _showSnackBar('🎉 Lote procesado: $sucessCount éxitos, $errorCount errores');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro de asistencias'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_trabajadoresEnCola.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Badge(
                  label: Text('${_trabajadoresEnCola.length}'),
                  backgroundColor: Colors.orange,
                  textColor: Colors.white,
                  child: Icon(Icons.group),
                ),
              ),
            ),
        ],
      ),
      body: _loading && !_dataLoaded
          ? Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Mensaje del último registro
                      if (_lastMessage != null) ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Expanded(child: Text(_lastMessage!, style: TextStyle(color: Colors.green.shade800))),
                              IconButton(
                                icon: Icon(Icons.close, size: 20),
                                onPressed: () => setState(() => _lastMessage = null),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                      
                      // Búsqueda de trabajadores
                      Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Buscar Trabajadores:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 12),
                              TextField(
                                controller: _trabajadorSearchController,
                                decoration: InputDecoration(
                                  hintText: 'Buscar por nombre o DNI...',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                onChanged: (query) {
                                  _filterTrabajadores(query);
                                  setState(() {
                                    _showTrabajadorList = query.isNotEmpty;
                                  });
                                },
                                onTap: () {
                                  setState(() {
                                    _showTrabajadorList = _trabajadorSearchController.text.isNotEmpty;
                                  });
                                },
                              ),
                              
                              // Lista de resultados de búsqueda
                              if (_showTrabajadorList) ...[
                                SizedBox(height: 8),
                                Container(
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: _trabajadoresFiltrados.isEmpty
                                      ? Center(child: Text('No se encontraron trabajadores'))
                                      : ListView.builder(
                                          itemCount: _trabajadoresFiltrados.length,
                                          itemBuilder: (context, index) {
                                            final trabajador = _trabajadoresFiltrados[index];
                                            final isInQueue = _trabajadoresEnCola.any((t) => t.id == trabajador.id);
                                            
                                            return ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: isInQueue ? Colors.green : Colors.blue,
                                                child: Text(trabajador.nombre.isNotEmpty ? trabajador.nombre[0].toUpperCase() : '?'),
                                                foregroundColor: Colors.white,
                                              ),
                                              title: Text(trabajador.nombre),
                                              subtitle: Text(trabajador.dni ?? 'Sin DNI'),
                                              trailing: isInQueue 
                                                  ? Icon(Icons.check_circle, color: Colors.green)
                                                  : Icon(Icons.add_circle_outline, color: Colors.blue),
                                              onTap: () {
                                                if (!isInQueue) {
                                                  _addTrabajadorToCola(trabajador);
                                                }
                                              },
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Cola de trabajadores seleccionados
                      if (_trabajadoresEnCola.isNotEmpty) ...[
                        Card(
                          elevation: 3,
                          color: Colors.orange.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.group, color: Colors.orange.shade700),
                                    SizedBox(width: 8),
                                    Text('Cola de Trabajadores (${_trabajadoresEnCola.length})', 
                                         style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Container(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _trabajadoresEnCola.length,
                                    itemBuilder: (context, index) {
                                      final trabajador = _trabajadoresEnCola[index];
                                      final isProcessing = _processingBatch && index == _currentWorkerIndex;
                                      
                                      return Container(
                                        width: 120,
                                        margin: EdgeInsets.only(right: 8),
                                        child: Card(
                                          color: isProcessing ? Colors.green.shade100 : Colors.white,
                                          child: Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: isProcessing ? Colors.green : Colors.orange,
                                                  child: isProcessing 
                                                      ? SizedBox(
                                                          width: 16, 
                                                          height: 16,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                          ),
                                                        )
                                                      : Text(trabajador.nombre.isNotEmpty ? trabajador.nombre[0].toUpperCase() : '?'),
                                                  foregroundColor: Colors.white,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  trabajador.nombre.length > 12 
                                                      ? '${trabajador.nombre.substring(0, 12)}...'
                                                      : trabajador.nombre,
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                ),
                                                SizedBox(height: 4),
                                                if (!_processingBatch)
                                                  InkWell(
                                                    onTap: () => _removeTrabajadorFromCola(trabajador),
                                                    child: Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],

                      // Selector de obra (persistente)
                      Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Obra:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              SizedBox(height: 8),
                              DropdownButton<Obra>(
                                value: _selectedObra,
                                hint: Text('Seleccionar obra'),
                                isExpanded: true,
                                items: _obras.map((obra) {
                                  // Verificar si la obra tiene GPS
                                  bool hasGPS = obra.lat != null && obra.lng != null && 
                                               obra.lat!.trim().isNotEmpty && obra.lng!.trim().isNotEmpty;
                                  
                                  return DropdownMenuItem<Obra>(
                                    value: obra,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            obra.nombre,
                                            style: TextStyle(
                                              color: hasGPS ? Colors.black : Colors.red.shade600,
                                              fontWeight: hasGPS ? FontWeight.normal : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (!hasGPS)
                                          Icon(
                                            Icons.warning_amber,
                                            color: Colors.orange,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (valor) {
                                  setState(() {
                                    _selectedObra = valor;
                                  });
                                  
                                  if (valor != null) {
                                    // Verificar GPS inmediatamente al seleccionar
                                    bool hasGPS = valor.lat != null && valor.lng != null && 
                                                 valor.lat!.trim().isNotEmpty && valor.lng!.trim().isNotEmpty;
                                    
                                    if (!hasGPS) {
                                      _showSnackBar('⚠️ La obra "${valor.nombre}" no tiene ubicación GPS configurada. Edítala para agregar coordenadas.');
                                    } else {
                                      _calculateDistanceToObra();
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Control GPS optimizado
                      Card(
                        elevation: 3,
                        color: _currentLocation != null ? Colors.green.shade50 : Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _currentLocation != null ? Icons.location_on : Icons.location_off,
                                    color: _currentLocation != null ? Colors.green : Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Ubicación GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Spacer(),
                                  if (_locationTimestamp != null && _currentLocation != null)
                                    Text(
                                      'Actualizada: ${DateTime.now().difference(_locationTimestamp!).inMinutes}min',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                              
                              SizedBox(height: 12),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _gettingLocation ? null : _getCurrentLocation,
                                      icon: _gettingLocation 
                                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                          : Icon(Icons.my_location),
                                      label: Text(_gettingLocation ? 'Obteniendo...' : 
                                                  _currentLocation != null ? 'Actualizar GPS' : 'Obtener Ubicación'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _currentLocation != null ? Colors.green : Colors.orange,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              if (_locationError != null) ...[
                                SizedBox(height: 8),
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error, color: Colors.red, size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _locationError!,
                                          style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              if (_currentLocation != null && _selectedObra != null && _distanceToObra != null) ...[
                                SizedBox(height: 12),
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _canMarkAttendance() ? Colors.green.shade100 : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _canMarkAttendance() ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _canMarkAttendance() ? Icons.check_circle : Icons.cancel,
                                        color: _canMarkAttendance() ? Colors.green : Colors.red,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _canMarkAttendance() 
                                              ? '✅ Dentro del radio: ${_distanceToObra!.toStringAsFixed(0)}m'
                                              : '❌ Fuera del radio: ${_distanceToObra!.toStringAsFixed(0)}m (Máx: ${_selectedObra?.radioMetros ?? 0}m)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _canMarkAttendance() ? Colors.green.shade700 : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Botón de Registro de Asistencia (movido abajo del GPS)
                      if (_trabajadoresEnCola.isNotEmpty) ...[
                        Card(
                          elevation: 3,
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  'Registrar Asistencia',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Se procesarán ${_trabajadoresEnCola.length} trabajador(es) con un solo GPS',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                                SizedBox(height: 12),
                                
                                if (_processingBatch) ...[
                                  Column(
                                    children: [
                                      LinearProgressIndicator(
                                        value: _currentWorkerIndex / _trabajadoresEnCola.length,
                                        backgroundColor: Colors.grey.shade300,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Procesando ${_currentWorkerIndex + 1} de ${_trabajadoresEnCola.length}',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      if (_currentWorkerIndex < _trabajadoresEnCola.length)
                                        Text(
                                          'Actual: ${_trabajadoresEnCola[_currentWorkerIndex].nombre}',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                    ],
                                  ),
                                ] else ...[
                                  ElevatedButton.icon(
                                    onPressed: _selectedObra != null && _currentLocation != null && !_loading 
                                        ? _processBatchMarkings 
                                        : null,
                                    icon: Icon(Icons.check_circle),
                                    label: Text('Registrar'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      foregroundColor: Colors.white,
                                      minimumSize: Size(double.infinity, 50),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Espaciado menor para mejor UI
                      SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  String _getAttendanceMessage() {
    if (_lastTipoMarcaje == null) {
      return 'No hay marcajes previos hoy.';
    } else if (_lastTipoMarcaje == 'entrada' && _tipoMarcaje == 'entrada') {
      return 'Ya marcaste una ENTRADA hoy. Selecciona SALIDA.';
    } else if (_lastTipoMarcaje == 'salida' && _tipoMarcaje == 'salida') {
      return 'Ya marcaste una SALIDA hoy. Selecciona ENTRADA.';
    } else if (_distanceToObra != null && _selectedObra != null && _distanceToObra! > (_selectedObra!.radioMetros ?? 100)) {
      return 'Estás muy lejos de la obra (${_distanceToObra!.toStringAsFixed(0)}m). Acércate más.';
    }
    return 'Marcaje válido';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
