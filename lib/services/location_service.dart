import 'package:geolocator/geolocator.dart';

/// Posición GPS lista para enviar en un marcaje.
class Ubicacion {
  final double lat;
  final double lng;

  /// Radio de incertidumbre reportado por el GPS, en metros.
  final double precisionMetros;

  /// true si Android indica que viene de una app de ubicación falsa.
  final bool simulada;
  final DateTime obtenidaEn;

  const Ubicacion({
    required this.lat,
    required this.lng,
    required this.precisionMetros,
    required this.simulada,
    required this.obtenidaEn,
  });

  bool esReciente([Duration maxEdad = const Duration(minutes: 2)]) =>
      DateTime.now().difference(obtenidaEn) <= maxEdad;
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}

/// Ubicación del dispositivo con `geolocator` (Android, iOS y web).
class LocationService {
  static const Duration _timeout = Duration(seconds: 20);

  static Future<Ubicacion> obtenerUbicacion() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('El GPS está apagado. Actívalo para marcar asistencia.');
    }

    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw LocationException('Se necesita permiso de ubicación para marcar asistencia.');
    }
    if (permiso == LocationPermission.deniedForever) {
      throw LocationException(
          'El permiso de ubicación está bloqueado. Habilítalo en Ajustes > Aplicaciones > LaborLog.');
    }

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _timeout,
        ),
      );
      return Ubicacion(
        lat: p.latitude,
        lng: p.longitude,
        precisionMetros: p.accuracy,
        simulada: p.isMocked,
        obtenidaEn: DateTime.now(),
      );
    } on LocationServiceDisabledException {
      throw LocationException('El GPS está apagado. Actívalo para marcar asistencia.');
    } catch (e) {
      throw LocationException('No se pudo obtener la ubicación. Sal a cielo abierto e intenta de nuevo.');
    }
  }

  /// Compatibilidad con las pantallas existentes (formulario de obras, marcaje web).
  static Future<Map<String, double>?> getCurrentPosition() async {
    final u = await obtenerUbicacion();
    return {
      'latitude': u.lat,
      'longitude': u.lng,
      'accuracy': u.precisionMetros,
    };
  }
}
