import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/user.dart';

class AuthService {
  static String? _token;
  static UsuarioAdmin? _currentUser;

  static String? get token => _token;
  static UsuarioAdmin? get currentUser => _currentUser;
  static bool get isLoggedIn => _token != null;

  /// admin y superadmin gestionan catálogos y planillas; supervisor solo marca y consulta.
  static bool get isAdmin {
    final rol = _currentUser?.rol;
    return rol == 'admin' || rol == 'superadmin';
  }

  // Headers comunes para requests autenticados
  static Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

  Future<bool> login(String email, String password) async {
    try {
      print('🔐 Iniciando login...');
      print('📧 Email: $email');
      print('🌐 URL: ${Constants.apiUrl}/login');
      
      final response = await http.post(
        Uri.parse('${Constants.apiUrl}/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}',
      );
      
      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        print('✅ Token recibido: ${_token!.substring(0, 20)}...');
        
        // Obtener información del usuario
        await _fetchCurrentUser();
        return true;
      }
      
      print('❌ Login failed: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('💥 Login error: $e');
    }
    return false;
  }

  Future<void> _fetchCurrentUser() async {
    if (_token == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/me'),
        headers: authHeaders,
      );
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _currentUser = UsuarioAdmin(
          id: userData['id'],
          nombre: userData['nombre'] ?? userData['user'],
          email: userData['user'], // El backend devuelve 'user' como email
          rol: userData['rol'],
        );
      }
    } catch (e) {
      print('Error fetching user: $e');
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
  }

  // Verificar si el token sigue siendo válido
  Future<bool> validateToken() async {
    if (_token == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('${Constants.apiUrl}/me'),
        headers: authHeaders,
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Token validation error: $e');
      return false;
    }
  }
}
