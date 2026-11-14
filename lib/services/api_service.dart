import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_config.dart';
import '../models/trabajador.dart';
import '../models/obra.dart';
import '../models/attendance.dart';
import '../models/dispositivo.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  static String get baseUrl => AppConfig.apiUrl;

  // Helper para manejo de errores de respuesta: usa el mensaje del backend
  // (campo "error"), p. ej. "Fuera del área de la obra: está a 120 m (máximo 50 m)".
  static void _checkResponse(http.Response response) {
    if (response.statusCode >= 400) {
      String mensaje = 'Error ${response.statusCode}';
      try {
        final body = json.decode(utf8.decode(response.bodyBytes));
        if (body is Map && body['error'] != null) {
          mensaje = body['error'].toString();
        }
      } catch (_) {
        // cuerpo no JSON: se queda el mensaje genérico
      }
      throw ApiException(response.statusCode, mensaje);
    }
  }

  // CRUD Trabajadores
  static Future<List<Trabajador>> getTrabajadores() async {
    final response = await http.get(
      Uri.parse('$baseUrl/trabajadores/'),
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Trabajador.fromJson(json)).toList();
  }

  static Future<Trabajador> createTrabajador(Trabajador trabajador) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trabajadores/'),
      headers: AuthService.authHeaders,
      body: json.encode(trabajador.toJson()),
    );
    _checkResponse(response);
    
    return Trabajador.fromJson(json.decode(response.body));
  }

  static Future<Trabajador> getTrabajador(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/trabajadores/$id'),
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    
    return Trabajador.fromJson(json.decode(response.body));
  }

  static Future<Trabajador> updateTrabajador(String id, Trabajador trabajador) async {
    final response = await http.put(
      Uri.parse('$baseUrl/trabajadores/$id'),
      headers: AuthService.authHeaders,
      body: json.encode(trabajador.toJson()),
    );
    _checkResponse(response);
    
    return Trabajador.fromJson(json.decode(response.body));
  }

  /// Registra el rostro (huella + foto alineada). Requiere sesión de supervisor o admin.
  static Future<Trabajador> registrarRostro(String trabajadorId, String huellaB64, String fotoB64) async {
    final response = await http.put(
      Uri.parse('$baseUrl/trabajadores/$trabajadorId/rostro'),
      headers: AuthService.authHeaders,
      body: json.encode({
        'huella_b64': huellaB64,
        'foto_jpeg_b64': fotoB64,
        'consentimiento': true,
        'modelo': 'sface-2021dec',
      }),
    );
    _checkResponse(response);
    return Trabajador.fromJson(json.decode(utf8.decode(response.bodyBytes)));
  }

  static Future<Trabajador> borrarRostro(String trabajadorId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/trabajadores/$trabajadorId/rostro'),
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    return Trabajador.fromJson(json.decode(utf8.decode(response.bodyBytes)));
  }

  // CRUD Obras
  static Future<List<Obra>> getObras() async {
    final response = await http.get(
      Uri.parse('$baseUrl/obras/'),
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Obra.fromJson(json)).toList();
  }

  static Future<Obra> createObra(Obra obra) async {
    final response = await http.post(
      Uri.parse('$baseUrl/obras/'),
      headers: AuthService.authHeaders,
      body: json.encode(obra.toJson()),
    );
    _checkResponse(response);
    
    return Obra.fromJson(json.decode(response.body));
  }

  static Future<Obra> updateObra(int id, Obra obra) async {
    final response = await http.put(
      Uri.parse('$baseUrl/obras/$id'),
      headers: AuthService.authHeaders,
      body: json.encode(obra.toJson()),
    );
    _checkResponse(response);
    
    return Obra.fromJson(json.decode(response.body));
  }

  // CRUD Marcajes
  static Future<List<Marcaje>> getMarcajes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/marcajes/'),
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Marcaje.fromJson(json)).toList();
  }

  static Future<Marcaje> createMarcaje(Marcaje marcaje) async {
    final response = await http.post(
      Uri.parse('$baseUrl/marcajes/'),
      headers: AuthService.authHeaders,
      body: json.encode(marcaje.toJson()),
    );
    _checkResponse(response);
    
    return Marcaje.fromJson(json.decode(response.body));
  }

  static Future<List<Marcaje>> getMarcajesTrabajador(String trabajadorId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/trabajadores/$trabajadorId/marcajes'),
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Marcaje.fromJson(json)).toList();
  }

  // CRUD Dispositivos
  static Future<List<Dispositivo>> getDispositivos() async {
    final response = await http.get(
      Uri.parse('$baseUrl/dispositivos/'),
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    
    final List<dynamic> data = json.decode(response.body);
    return data.map((json) => Dispositivo.fromJson(json)).toList();
  }

  static Future<Dispositivo> createDispositivo(Dispositivo dispositivo) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dispositivos/'),
      headers: AuthService.authHeaders,
      body: json.encode(dispositivo.toJson()),
    );
    _checkResponse(response);
    
    return Dispositivo.fromJson(json.decode(response.body));
  }

  /// Cambia solo los campos indicados (obra asignada, activo, nombre).
  static Future<Dispositivo> updateDispositivo(String id, Map<String, dynamic> cambios) async {
    final response = await http.put(
      Uri.parse('$baseUrl/dispositivos/$id'),
      headers: AuthService.authHeaders,
      body: json.encode(cambios),
    );
    _checkResponse(response);
    return Dispositivo.fromJson(json.decode(utf8.decode(response.bodyBytes)));
  }

  /// Genera un token nuevo (el anterior deja de funcionar). Viene en Dispositivo.token.
  static Future<Dispositivo> rotarTokenDispositivo(String id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/dispositivos/$id/token'),
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    return Dispositivo.fromJson(json.decode(utf8.decode(response.bodyBytes)));
  }

  // =================================================================
  // FUNCIONALIDAD DE PLANILLAS
  // =================================================================

  // Obtener datos de planilla con cálculos para un período
  static Future<Map<String, dynamic>> getPlanillaDatos({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required double precioHora,
    String? trabajadorId,
  }) async {
    final queryParams = {
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'precio_hora': precioHora.toString(),
      if (trabajadorId != null) 'trabajador_id': trabajadorId,
    };

    final uri = Uri.parse('$baseUrl/planillas/calcular')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    
    return json.decode(response.body);
  }

  // Generar y descargar planilla en PDF
  static Future<List<int>> generarPlanillaPDF({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required double precioHora,
    String? trabajadorId,
    String moneda = 'USD',
  }) async {
    final queryParams = {
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'precio_hora': precioHora.toString(),
      'moneda': moneda,
      if (trabajadorId != null) 'trabajador_id': trabajadorId,
    };

    final uri = Uri.parse('$baseUrl/planillas/generar-pdf')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    
    return response.bodyBytes;
  }

  // Generar y descargar planilla en Excel
  static Future<List<int>> generarPlanillaExcel({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required double precioHora,
    String? trabajadorId,
    String moneda = 'USD',
  }) async {
    final queryParams = {
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'precio_hora': precioHora.toString(),
      'moneda': moneda,
      if (trabajadorId != null) 'trabajador_id': trabajadorId,
    };

    final uri = Uri.parse('$baseUrl/planillas/generar-excel')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    
    return response.bodyBytes;
  }

  // Obtener resumen de planilla para vista previa
  static Future<Map<String, dynamic>> getResumenPlanilla({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required double precioHora,
  }) async {
    final queryParams = {
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'precio_hora': precioHora.toString(),
    };

    final uri = Uri.parse('$baseUrl/planillas/resumen')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: AuthService.authHeaders,
    );
    _checkResponse(response);
    
    return json.decode(response.body);
  }
}
