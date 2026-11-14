import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

/// Dirección del backend. En web y desarrollo es localhost; en un teléfono se
/// configura al activar el modo kiosco (p. ej. https://laborlog.miempresa.com).
/// También se puede fijar al compilar: flutter build apk --dart-define=API_URL=https://...
class AppConfig {
  static const String _claveApiUrl = 'api_url';
  static const String apiUrlPorDefecto =
      String.fromEnvironment('API_URL', defaultValue: Constants.apiUrl);

  static String _apiUrl = apiUrlPorDefecto;
  static String get apiUrl => _apiUrl;

  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiUrl = prefs.getString(_claveApiUrl) ?? apiUrlPorDefecto;
    } catch (_) {
      _apiUrl = apiUrlPorDefecto;
    }
  }

  static Future<void> guardarApiUrl(String url) async {
    _apiUrl = normalizarUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveApiUrl, _apiUrl);
  }

  /// Usado en pruebas.
  static void fijarApiUrl(String url) => _apiUrl = normalizarUrl(url);

  static String normalizarUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) return apiUrlPorDefecto;
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
