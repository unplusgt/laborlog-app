import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/attendance.dart';
import '../models/trabajador.dart';
import '../models/obra.dart';

// Clase para agrupar marcajes por trabajador en un día
class TrabajadorDatos {
  final Trabajador trabajador;
  final List<Marcaje> marcajes;
  
  TrabajadorDatos({required this.trabajador, required this.marcajes});
}

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
  List<Marcaje> _marcajes = [];
  List<Trabajador> _trabajadores = [];
  List<Obra> _obras = [];
  bool _loading = true;
  String? _error;
  
  // Variables para filtros de fecha
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now();
  bool _mostrarFiltros = false;
  
  // Variable para búsqueda de trabajadores
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Lista filtrada de trabajadores con sus marcajes
  List<TrabajadorDatos> _trabajadoresFiltrados = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Inicializar fechas: por defecto hoy
    final hoy = DateTime.now();
    _fechaInicio = DateTime(hoy.year, hoy.month, hoy.day);
    _fechaFin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refrescar datos cuando la app vuelve al foco
      _loadMarcajes();
    }
  }

  Future<void> _loadData() async {
    await _loadMarcajes();
    await _loadTrabajadores();
    await _loadObras();
    _filtrarYAgruparMarcajes(); // Aplicar filtros después de cargar datos
  }

  // Método para filtrar marcajes por fechas y agrupar por trabajador
  void _filtrarYAgruparMarcajes() {
    // Filtrar marcajes por rango de fechas
    final marcajesFiltrados = _marcajes.where((marcaje) {
      return marcaje.timestampLocal.isAfter(_fechaInicio.subtract(Duration(seconds: 1))) &&
             marcaje.timestampLocal.isBefore(_fechaFin.add(Duration(minutes: 1)));
    }).toList();

    // Agrupar marcajes por trabajador
    Map<String, List<Marcaje>> marcajesPorTrabajador = {};
    
    for (final marcaje in marcajesFiltrados) {
      final trabajadorId = marcaje.trabajadorId;
      if (!marcajesPorTrabajador.containsKey(trabajadorId)) {
        marcajesPorTrabajador[trabajadorId] = [];
      }
      marcajesPorTrabajador[trabajadorId]!.add(marcaje);
    }

    // Crear lista de TrabajadorDatos con marcajes ordenados
    List<TrabajadorDatos> todosLosTrabajadores = [];
    marcajesPorTrabajador.forEach((trabajadorId, marcajes) {
      final trabajador = _trabajadores.firstWhere(
        (t) => t.id == trabajadorId,
        orElse: () => Trabajador(id: trabajadorId, nombre: 'Trabajador no encontrado'),
      );
      
      // Ordenar marcajes del trabajador por hora
      marcajes.sort((a, b) => a.timestampLocal.compareTo(b.timestampLocal));
      
      todosLosTrabajadores.add(TrabajadorDatos(
        trabajador: trabajador,
        marcajes: marcajes,
      ));
    });

    // Filtrar por búsqueda si hay query
    if (_searchQuery.isNotEmpty) {
      todosLosTrabajadores = todosLosTrabajadores.where((trabajadorData) {
        final trabajador = trabajadorData.trabajador;
        final nombreMatch = trabajador.nombre.toLowerCase().contains(_searchQuery.toLowerCase());
        final dniMatch = trabajador.dni?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
        return nombreMatch || dniMatch;
      }).toList();
    }
    
    // Ordenar trabajadores alfabéticamente
    todosLosTrabajadores.sort((a, b) => a.trabajador.nombre.compareTo(b.trabajador.nombre));
    
    setState(() {
      _trabajadoresFiltrados = todosLosTrabajadores;
    });
  }

  Future<void> _loadTrabajadores() async {
    try {
      final trabajadores = await ApiService.getTrabajadores();
      setState(() {
        _trabajadores = trabajadores;
      });
    } catch (e) {
      print('Error cargando trabajadores: $e');
    }
  }

  Future<void> _loadObras() async {
    try {
      final obras = await ApiService.getObras();
      setState(() {
        _obras = obras;
      });
    } catch (e) {
      print('Error cargando obras: $e');
    }
  }

  Future<void> _loadMarcajes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      print('📊 Cargando marcajes desde API...');
      final marcajes = await ApiService.getMarcajes();
      print('📊 Marcajes obtenidos: ${marcajes.length}');
      
      // Log cada marcaje para debug
      for (var i = 0; i < marcajes.length && i < 5; i++) {
        final m = marcajes[i];
        print('📋 Marcaje ${i+1}: ${m.tipo} - Trabajador: ${m.trabajadorId} - Obra: ${m.obraId} - Fecha: ${m.timestampLocal}');
      }
      
      setState(() {
        _marcajes = marcajes;
        // Ordenar por fecha más reciente primero
        _marcajes.sort((a, b) => b.timestampLocal.compareTo(a.timestampLocal));
      });
      
      // Filtrar después de cargar
      if (_trabajadores.isNotEmpty) {
        _filtrarYAgruparMarcajes();
      }
    } catch (e) {
      print('❌ Error cargando marcajes: $e');
      setState(() {
        _error = 'Error al cargar historial: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  // Método para mostrar selector de fecha de inicio
  Future<void> _seleccionarFechaInicio() async {
    try {
      final fecha = await showDatePicker(
        context: context,
        initialDate: _fechaInicio,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(Duration(days: 1)),
        helpText: 'Seleccionar fecha de inicio',
        cancelText: 'Cancelar',
        confirmText: 'Confirmar',
      );
      
      if (fecha != null) {
        setState(() {
          _fechaInicio = DateTime(fecha.year, fecha.month, fecha.day);
          // Si fecha inicio es después de fecha fin, ajustar fecha fin
          if (_fechaInicio.isAfter(_fechaFin)) {
            _fechaFin = DateTime(_fechaInicio.year, _fechaInicio.month, _fechaInicio.day, 23, 59, 59);
          }
        });
        _filtrarYAgruparMarcajes();
      }
    } catch (e) {
      print('Error al seleccionar fecha de inicio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar fecha')),
      );
    }
  }

  // Método para mostrar selector de fecha de fin
  Future<void> _seleccionarFechaFin() async {
    try {
      final fecha = await showDatePicker(
        context: context,
        initialDate: _fechaFin,
        firstDate: _fechaInicio,
        lastDate: DateTime.now().add(Duration(days: 1)),
        helpText: 'Seleccionar fecha de fin',
        cancelText: 'Cancelar',
        confirmText: 'Confirmar',
      );
      
      if (fecha != null) {
        setState(() {
          _fechaFin = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);
        });
        _filtrarYAgruparMarcajes();
      }
    } catch (e) {
      print('Error al seleccionar fecha de fin: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar fecha')),
      );
    }
  }

  // Métodos rápidos para filtros comunes
  void _filtrarHoy() {
    final hoy = DateTime.now();
    setState(() {
      _fechaInicio = DateTime(hoy.year, hoy.month, hoy.day);
      _fechaFin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
    });
    _filtrarYAgruparMarcajes();
  }

  void _filtrarEstaSemana() {
    final hoy = DateTime.now();
    final inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
    setState(() {
      _fechaInicio = DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
      _fechaFin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
    });
    _filtrarYAgruparMarcajes();
  }

  void _filtrarEsteMes() {
    final hoy = DateTime.now();
    setState(() {
      _fechaInicio = DateTime(hoy.year, hoy.month, 1);
      _fechaFin = DateTime(hoy.year, hoy.month + 1, 0, 23, 59, 59);
    });
    _filtrarYAgruparMarcajes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historial de Asistencia'),
        actions: [
          IconButton(
            icon: Icon(_mostrarFiltros ? Icons.filter_list : Icons.filter_list_alt),
            onPressed: () {
              setState(() {
                _mostrarFiltros = !_mostrarFiltros;
              });
            },
            tooltip: 'Filtros y búsqueda',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de filtros y búsqueda
          if (_mostrarFiltros) _buildFilterPanel(),
          
          // Indicador de rango de fechas seleccionado
          _buildDateIndicator(),
          
          // Lista de trabajadores
          Expanded(
            child: _loading
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
                              onPressed: _loadMarcajes,
                              child: Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _trabajadoresFiltrados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  _searchQuery.isNotEmpty 
                                    ? 'No se encontraron trabajadores con "$_searchQuery"'
                                    : 'No hay registros en el período seleccionado'
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty 
                                    ? 'Prueba con otro término de búsqueda'
                                    : 'Selecciona un rango diferente', 
                                  style: TextStyle(color: Colors.grey)
                                ),
                                SizedBox(height: 16),
                                if (_searchQuery.isNotEmpty)
                                  ElevatedButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                      _filtrarYAgruparMarcajes();
                                    },
                                    child: Text('Limpiar búsqueda'),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: _filtrarHoy,
                                    child: Text('Ver hoy'),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: _trabajadoresFiltrados.length,
                              itemBuilder: (context, index) {
                                final trabajadorData = _trabajadoresFiltrados[index];
                                return _buildTrabajadorCard(trabajadorData);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // Widget para el panel de filtros y búsqueda
  Widget _buildFilterPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de búsqueda
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar trabajador por nombre o DNI...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty 
                ? IconButton(
                    icon: Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      _filtrarYAgruparMarcajes();
                    },
                  )
                : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _filtrarYAgruparMarcajes();
            },
          ),
          SizedBox(height: 16),
          
          // Botones de filtros rápidos
          Text('Filtros rápidos:', style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildQuickFilterButton('Hoy', _filtrarHoy),
              _buildQuickFilterButton('Semana', _filtrarEstaSemana),
              _buildQuickFilterButton('Mes', _filtrarEsteMes),
            ],
          ),
          SizedBox(height: 16),
          
          // Selectores de fecha personalizada
          Text('Rango personalizado:', style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDatePickerButton(
                  'Fecha inicio',
                  _fechaInicio,
                  _seleccionarFechaInicio,
                  Icons.calendar_today,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildDatePickerButton(
                  'Fecha fin',
                  _fechaFin,
                  _seleccionarFechaFin,
                  Icons.event,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget para indicador de filtros activos
  Widget _buildDateIndicator() {
    final totalMarcajes = _trabajadoresFiltrados.fold<int>(0, (sum, t) => sum + t.marcajes.length);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
      ),
      child: Column(
        children: [
          Text(
            '📅 ${_formatDate(_fechaInicio)} - ${_formatDate(_fechaFin)}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${_trabajadoresFiltrados.length} trabajador(es) • $totalMarcajes marcaje(s)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // Widget para botones de filtro rápido
  Widget _buildQuickFilterButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade100,
        foregroundColor: Colors.blue.shade700,
        elevation: 1,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // Widget para botón selector de fecha
  Widget _buildDatePickerButton(String label, DateTime fecha, VoidCallback onPressed, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(_formatDate(fecha), style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              side: BorderSide(color: Colors.grey.shade300),
              elevation: 1,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  // Formato corto para fechas
  String _formatDate(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  // Widget para tarjeta de trabajador
  Widget _buildTrabajadorCard(TrabajadorDatos trabajadorData) {
    final trabajador = trabajadorData.trabajador;
    final marcajes = trabajadorData.marcajes;
    
    // Contar entradas y salidas
    final entradas = marcajes.where((m) => m.tipo.toLowerCase() == 'entrada').length;
    final salidas = marcajes.where((m) => m.tipo.toLowerCase() == 'salida').length;
    
    // Determinar estado
    String estado = 'Completo';
    Color estadoColor = Colors.green;
    if (entradas > salidas) {
      estado = 'En trabajo';
      estadoColor = Colors.orange;
    } else if (entradas == 0) {
      estado = 'Sin marcajes';
      estadoColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: estadoColor.withOpacity(0.1),
              child: Text(
                trabajador.nombre.isNotEmpty 
                  ? trabajador.nombre[0].toUpperCase()
                  : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: estadoColor,
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trabajador.nombre,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (trabajador.dni?.isNotEmpty == true)
                    Text(
                      'DNI: ${trabajador.dni}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: EdgeInsets.only(left: 52),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: estadoColor),
                  SizedBox(width: 4),
                  Text(estado, style: TextStyle(color: estadoColor, fontWeight: FontWeight.w500)),
                  Spacer(),
                  Text(
                    '$entradas entrada(s) • $salidas salida(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: marcajes.map((marcaje) => _buildMarcajeItem(marcaje)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para item de marcaje individual
  Widget _buildMarcajeItem(Marcaje marcaje) {
    final isEntrada = marcaje.tipo.toLowerCase() == 'entrada';
    final color = isEntrada ? Colors.green : Colors.red;
    final icon = isEntrada ? Icons.login : Icons.logout;

    // Buscar nombre de obra
    final obra = _obras.firstWhere(
      (o) => o.id == marcaje.obraId,
      orElse: () => Obra(id: 0, nombre: 'Obra no encontrada'),
    );

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  marcaje.tipo.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  _formatDateTime(marcaje.timestampLocal),
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  '🏭 ${obra.nombre}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Icon(
            marcaje.timestampServer != null ? Icons.cloud_done : Icons.cloud_off,
            color: marcaje.timestampServer != null ? Colors.green : Colors.grey,
            size: 16,
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
           '${dateTime.hour.toString().padLeft(2, '0')}:'
           '${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
