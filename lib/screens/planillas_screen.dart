import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/attendance.dart';
import '../models/trabajador.dart';
import '../models/obra.dart';
import 'package:universal_html/html.dart' as html;

// Clase para agrupar datos de planilla por trabajador
class TrabajadorPlanilla {
  final Trabajador trabajador;
  final List<Marcaje> marcajes;
  final int diasTrabajados;
  final double horasTotales;
  final double horasExtras;
  final double salarioBruto;
  
  TrabajadorPlanilla({
    required this.trabajador,
    required this.marcajes,
    required this.diasTrabajados,
    required this.horasTotales,
    required this.horasExtras,
    required this.salarioBruto,
  });
}

class PlanillasScreen extends StatefulWidget {
  @override
  _PlanillasScreenState createState() => _PlanillasScreenState();
}

class _PlanillasScreenState extends State<PlanillasScreen> {
  List<Marcaje> _marcajes = [];
  List<Trabajador> _trabajadores = [];
  List<Obra> _obras = [];
  bool _loading = true;
  String? _error;
  
  // Variables para filtros de fecha
  DateTime _fechaInicio = DateTime.now();
  DateTime _fechaFin = DateTime.now();
  bool _mostrarFiltros = false;
  
  // Variables para configuración de planilla
  final TextEditingController _precioHoraController = TextEditingController();
  double _precioHora = 15.0; // Precio por defecto
  final int _horasNormalesDia = 8; // Horas normales por día
  
  // Variables para tipo de moneda
  String _tipoMoneda = 'USD'; // USD o GTQ
  String get _simboloMoneda => _tipoMoneda == 'USD' ? '\$' : 'Q';
  
  // Lista de monedas disponibles
  final List<Map<String, String>> _monedasDisponibles = [
    {'codigo': 'USD', 'nombre': 'Dólares', 'simbolo': '\$'},
    {'codigo': 'GTQ', 'nombre': 'Quetzales', 'simbolo': 'Q'},
  ];
  
  // Variable para búsqueda de trabajadores
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Lista filtrada de trabajadores con sus planillas
  List<TrabajadorPlanilla> _planillasProcesadas = [];
  
  // Variables para filtros rápidos
  String _filtroActual = 'hoy'; // 'hoy', 'semana', 'mes', 'personalizado'

  @override
  void initState() {
    super.initState();
    _precioHoraController.text = _precioHora.toString();
    _setFiltroRapido('hoy');
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _precioHoraController.dispose();
    super.dispose();
  }

  // Configurar filtros rápidos de fecha
  void _setFiltroRapido(String filtro) {
    final ahora = DateTime.now();
    
    switch (filtro) {
      case 'hoy':
        _fechaInicio = DateTime(ahora.year, ahora.month, ahora.day);
        _fechaFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
        break;
        
      case 'semana':
        // Lunes de esta semana
        int weekday = ahora.weekday;
        DateTime startOfWeek = ahora.subtract(Duration(days: weekday - 1));
        _fechaInicio = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        _fechaFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
        break;
        
      case 'mes':
        _fechaInicio = DateTime(ahora.year, ahora.month, 1);
        _fechaFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
        break;
    }
    
    setState(() {
      _filtroActual = filtro;
    });
    
    if (_trabajadores.isNotEmpty && _marcajes.isNotEmpty) {
      _procesarPlanillas();
    }
  }

  Future<void> _loadData() async {
    await _loadMarcajes();
    await _loadTrabajadores();
    await _loadObras();
    _procesarPlanillas();
  }

  Future<void> _loadTrabajadores() async {
    try {
      final trabajadores = await ApiService.getTrabajadores();
      setState(() {
        _trabajadores = trabajadores.where((t) => t.activo).toList(); // Solo trabajadores activos
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
      print('💼 Cargando marcajes para planillas...');
      final marcajes = await ApiService.getMarcajes();
      print('💼 Marcajes obtenidos: ${marcajes.length}');
      
      setState(() {
        _marcajes = marcajes;
      });
      
    } catch (e) {
      print('❌ Error cargando marcajes: $e');
      setState(() {
        _error = 'Error al cargar datos de planilla: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Procesar marcajes y calcular planillas por trabajador
  void _procesarPlanillas() {
    if (_marcajes.isEmpty || _trabajadores.isEmpty) {
      setState(() {
        _planillasProcesadas = [];
      });
      return;
    }

    // Filtrar marcajes por rango de fechas
    final marcajesFiltrados = _marcajes.where((marcaje) {
      return marcaje.timestampLocal.isAfter(_fechaInicio.subtract(Duration(seconds: 1))) &&
             marcaje.timestampLocal.isBefore(_fechaFin.add(Duration(minutes: 1)));
    }).toList();

    // Procesar cada trabajador
    List<TrabajadorPlanilla> planillas = [];
    
    for (final trabajador in _trabajadores) {
      // Obtener marcajes del trabajador
      final marcajesTrabajador = marcajesFiltrados
          .where((m) => m.trabajadorId == trabajador.id)
          .toList();

      if (marcajesTrabajador.isEmpty) continue;

      // Calcular estadísticas
      final estadisticas = _calcularEstadisticas(marcajesTrabajador);
      
      planillas.add(TrabajadorPlanilla(
        trabajador: trabajador,
        marcajes: marcajesTrabajador,
        diasTrabajados: estadisticas['diasTrabajados']?.toInt() ?? 0,
        horasTotales: estadisticas['horasTotales'] ?? 0.0,
        horasExtras: estadisticas['horasExtras'] ?? 0.0,
        salarioBruto: (estadisticas['horasTotales'] ?? 0.0) * _precioHora +
                     (estadisticas['horasExtras'] ?? 0.0) * _precioHora * 0.5, // Extras al 50% más
      ));
    }

    // Filtrar por búsqueda si hay query
    if (_searchQuery.isNotEmpty) {
      planillas = planillas.where((planilla) {
        final trabajador = planilla.trabajador;
        final nombreMatch = trabajador.nombre.toLowerCase().contains(_searchQuery.toLowerCase());
        final dniMatch = trabajador.dni?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
        return nombreMatch || dniMatch;
      }).toList();
    }
    
    // Ordenar por nombre
    planillas.sort((a, b) => a.trabajador.nombre.compareTo(b.trabajador.nombre));
    
    setState(() {
      _planillasProcesadas = planillas;
    });
  }

  // Calcular estadísticas de trabajo para un trabajador
  Map<String, double> _calcularEstadisticas(List<Marcaje> marcajes) {
    // Agrupar marcajes por día
    Map<String, List<Marcaje>> marcajesPorDia = {};
    
    for (final marcaje in marcajes) {
      final fechaKey = '${marcaje.timestampLocal.year}-${marcaje.timestampLocal.month}-${marcaje.timestampLocal.day}';
      marcajesPorDia.putIfAbsent(fechaKey, () => []);
      marcajesPorDia[fechaKey]!.add(marcaje);
    }

    int diasTrabajados = 0;
    double horasTotales = 0.0;
    double horasExtras = 0.0;

    // Procesar cada día
    for (final marcajesDia in marcajesPorDia.values) {
      // Separar entradas y salidas
      final entradas = marcajesDia.where((m) => m.tipo == 'entrada').toList();
      final salidas = marcajesDia.where((m) => m.tipo == 'salida').toList();

      if (entradas.isNotEmpty && salidas.isNotEmpty) {
        // Ordenar marcajes por timestamp
        entradas.sort((a, b) => a.timestampLocal.compareTo(b.timestampLocal));
        salidas.sort((a, b) => a.timestampLocal.compareTo(b.timestampLocal));

        // Calcular horas trabajadas (primera entrada - última salida)
        final primerEntrada = entradas.first.timestampLocal;
        final ultimaSalida = salidas.last.timestampLocal;
        
        final horasDia = ultimaSalida.difference(primerEntrada).inMinutes / 60.0;
        
        if (horasDia > 0) {
          diasTrabajados++;
          horasTotales += horasDia;
          
          // Calcular horas extras (más de 8 horas al día)
          if (horasDia > _horasNormalesDia) {
            horasExtras += horasDia - _horasNormalesDia;
          }
        }
      }
    }

    return {
      'diasTrabajados': diasTrabajados.toDouble(),
      'horasTotales': horasTotales,
      'horasExtras': horasExtras,
    };
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  // Mostrar selector de fecha de inicio
  Future<void> _seleccionarFechaInicio() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 1)),
      helpText: 'Seleccionar fecha de inicio',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    
    if (fecha != null) {
      setState(() {
        _fechaInicio = DateTime(fecha.year, fecha.month, fecha.day);
        _filtroActual = 'personalizado';
      });
      _procesarPlanillas();
    }
  }

  // Mostrar selector de fecha de fin
  Future<void> _seleccionarFechaFin() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaFin,
      firstDate: _fechaInicio,
      lastDate: DateTime.now().add(Duration(days: 1)),
      helpText: 'Seleccionar fecha de fin',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    
    if (fecha != null) {
      setState(() {
        _fechaFin = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);
        _filtroActual = 'personalizado';
      });
      _procesarPlanillas();
    }
  }

  // Actualizar precio por hora
  void _actualizarPrecioHora() {
    final nuevoPrecio = double.tryParse(_precioHoraController.text);
    if (nuevoPrecio != null && nuevoPrecio > 0) {
      setState(() {
        _precioHora = nuevoPrecio;
      });
      _procesarPlanillas(); // Recalcular con nuevo precio
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingrese un precio válido')),
      );
      _precioHoraController.text = _precioHora.toString();
    }
  }

  // Generar reporte en PDF
  Future<void> _generarPDF() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 16),
              Text('Generando PDF...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      final pdfBytes = await ApiService.generarPlanillaPDF(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        precioHora: _precioHora,
        moneda: _tipoMoneda,
      );

      // Crear nombre de archivo con fecha y moneda
      final fechaStr = '${_fechaInicio.day}-${_fechaInicio.month}-${_fechaInicio.year}_al_${_fechaFin.day}-${_fechaFin.month}-${_fechaFin.year}';
      final nombreArchivo = 'planilla_${fechaStr}_${_tipoMoneda}.pdf';

      // Crear blob y enlace de descarga para Flutter Web
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = nombreArchivo;
      
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('PDF descargado: $nombreArchivo')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error generando PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error al generar PDF: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // Generar reporte en Excel
  Future<void> _generarExcel() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(width: 16),
              Text('Generando Excel...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      final excelBytes = await ApiService.generarPlanillaExcel(
        fechaInicio: _fechaInicio,
        fechaFin: _fechaFin,
        precioHora: _precioHora,
        moneda: _tipoMoneda,
      );

      // Crear nombre de archivo con fecha y moneda
      final fechaStr = '${_fechaInicio.day}-${_fechaInicio.month}-${_fechaInicio.year}_al_${_fechaFin.day}-${_fechaFin.month}-${_fechaFin.year}';
      final nombreArchivo = 'planilla_${fechaStr}_${_tipoMoneda}.xlsx';

      // Crear blob y enlace de descarga para Flutter Web
      final blob = html.Blob([excelBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = nombreArchivo;
      
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Excel descargado: $nombreArchivo')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error generando Excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error al generar Excel: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  String _formatHoras(double horas) {
    final horasEnteras = horas.floor();
    final minutos = ((horas - horasEnteras) * 60).round();
    return '${horasEnteras}h ${minutos}m';
  }

  String _formatMoneda(double cantidad) {
    return '${_simboloMoneda}${cantidad.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generar Planilla'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () {
              setState(() {
                _mostrarFiltros = !_mostrarFiltros;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de configuración de precio por hora
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuración de planilla:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                
                Row(
                  children: [
                    // Selector de moneda
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Moneda:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButton<String>(
                              value: _tipoMoneda,
                              isExpanded: true,
                              underline: SizedBox(),
                              items: _monedasDisponibles.map((moneda) {
                                return DropdownMenuItem<String>(
                                  value: moneda['codigo'],
                                  child: Text('${moneda['simbolo']} ${moneda['nombre']}'),
                                );
                              }).toList(),
                              onChanged: (String? nuevaMoneda) {
                                if (nuevaMoneda != null) {
                                  setState(() {
                                    _tipoMoneda = nuevaMoneda;
                                  });
                                  _procesarPlanillas(); // Recalcular con nueva moneda
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: 16),
                    
                    // Precio por hora
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Precio por hora:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          TextField(
                            controller: _precioHoraController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              prefixText: _simboloMoneda,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onSubmitted: (_) => _actualizarPrecioHora(),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: 16),
                    
                    // Botón actualizar
                    ElevatedButton(
                      onPressed: _actualizarPrecioHora,
                      child: Text('Actualizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Panel de filtros si está habilitado
          if (_mostrarFiltros) ...[
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Column(
                children: [
                  // Filtros rápidos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFiltroRapido('Hoy', 'hoy'),
                      _buildFiltroRapido('Semana', 'semana'),
                      _buildFiltroRapido('Mes', 'mes'),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // Selección de fechas personalizadas
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fecha inicio:', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            GestureDetector(
                              onTap: _seleccionarFechaInicio,
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(_formatFecha(_fechaInicio)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fecha fin:', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            GestureDetector(
                              onTap: _seleccionarFechaFin,
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(_formatFecha(_fechaFin)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Campo de búsqueda
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar trabajador...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (query) {
                      setState(() {
                        _searchQuery = query;
                      });
                      _procesarPlanillas();
                    },
                  ),
                ],
              ),
            ),
          ],
          
          // Botones de acción
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generarPDF,
                    icon: Icon(Icons.picture_as_pdf),
                    label: Text('Generar PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generarExcel,
                    icon: Icon(Icons.table_chart),
                    label: Text('Generar Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de planillas
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 64, color: Colors.red),
                            SizedBox(height: 16),
                            Text('Error: $_error'),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refresh,
                              child: Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _planillasProcesadas.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No hay datos de planilla para el período seleccionado',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.builder(
                              itemCount: _planillasProcesadas.length,
                              itemBuilder: (context, index) {
                                final planilla = _planillasProcesadas[index];
                                return _buildPlanillaCard(planilla);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroRapido(String texto, String valor) {
    final activo = _filtroActual == valor;
    return GestureDetector(
      onTap: () => _setFiltroRapido(valor),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: activo ? Colors.white : Colors.black87,
            fontWeight: activo ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanillaCard(TrabajadorPlanilla planilla) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: ExpansionTile(
        title: Text(
          planilla.trabajador.nombre,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${planilla.diasTrabajados} días • ${_formatHoras(planilla.horasTotales)} • ${_formatMoneda(planilla.salarioBruto)}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem('DNI', planilla.trabajador.dni ?? 'N/A'),
                    ),
                    Expanded(
                      child: _buildInfoItem('Código', planilla.trabajador.codigoEmpresa ?? 'N/A'),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem('Días trabajados', '${planilla.diasTrabajados}'),
                    ),
                    Expanded(
                      child: _buildInfoItem('Horas totales', _formatHoras(planilla.horasTotales)),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem('Horas extras', _formatHoras(planilla.horasExtras)),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'Salario bruto',
                        _formatMoneda(planilla.salarioBruto),
                        isHighlight: true,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                _buildInfoItem('Marcajes', '${planilla.marcajes.length}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight ? Colors.green[700] : null,
          ),
        ),
      ],
    );
  }
}