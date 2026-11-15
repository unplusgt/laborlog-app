import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../utils/app_config.dart';

/// Sesión del usuario: inicio con código de empresa + usuario o email + contraseña.
class AuthService {
  static const _claveEmpresa = 'ultima_empresa';

  static String? _token;
  static UsuarioAdmin? _currentUser;

  static String? get token => _token;
  static UsuarioAdmin? get currentUser => _currentUser;
  static bool get isLoggedIn => _token != null;

  static String? get rol => _currentUser?.rol;
  static bool get isPlataforma => rol == Roles.plataforma;
  static bool get isSuperadmin => rol == Roles.superadmin;
  static bool get isJefe => rol == Roles.jefe;
  static bool get isSupervisor => rol == Roles.supervisor;

  /// superadmin y jefe: trabajadores, obras, dispositivos, usuarios.
  static bool get puedeGestionar => isSuperadmin || isJefe;

  /// Solo superadmin: planilla y configuración de pago.
  static bool get puedeVerPlanilla => isSuperadmin;

  /// Compatibilidad: antes "admin" era quien gestionaba.
  static bool get isAdmin => puedeGestionar;

  static Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  /// Última empresa con la que se inició sesión en este equipo.
  static Future<String> ultimaEmpresa() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_claveEmpresa) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<bool> login(String empresa, String usuario, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'empresa': empresa.trim().toLowerCase(),
          'username': usuario.trim(),
          'password': password,
        },
      );
      if (response.statusCode != 200) return false;
      _token = json.decode(response.body)['access_token'];
      await _fetchCurrentUser();
      if (_currentUser == null) {
        _token = null;
        return false;
      }
      try {
        await (await SharedPreferences.getInstance()).setString(_claveEmpresa, empresa.trim().toLowerCase());
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('Error de conexión en login: $e');
      return false;
    }
  }

  Future<void> _fetchCurrentUser() async {
    if (_token == null) return;
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/me'), headers: authHeaders);
      if (response.statusCode == 200) {
        _currentUser = UsuarioAdmin.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      }
    } catch (e) {
      debugPrint('Error obteniendo el usuario: $e');
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
  }

  Future<bool> validateToken() async {
    if (_token == null) return false;
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiUrl}/me'), headers: authHeaders);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
