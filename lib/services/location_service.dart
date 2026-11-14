import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class LocationService {
  static Future<Map<String, double>?> getCurrentPosition() async {
    if (!kIsWeb) {
      // Para dispositivos móviles se usaría geolocator
      return null;
    }
    
    try {
      // Para web usamos la API nativa del navegador
      final position = await _getCurrentPositionWeb();
      return {
        'latitude': position['latitude']!,
        'longitude': position['longitude']!,
      };
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      rethrow; // Propagar el error para mostrarlo al usuario
    }
  }
  
  static Future<Map<String, double>> _getCurrentPositionWeb() async {
    final navigator = html.window.navigator;
    final geolocation = navigator.geolocation;
    
    if (geolocation == null) {
      throw Exception('Geolocalización no soportada por el navegador');
    }
    
    final completer = Completer<Map<String, double>>();
    
    geolocation.getCurrentPosition().then((html.Geoposition position) {
      final coords = position.coords;
      if (coords != null) {
        completer.complete({
          'latitude': coords.latitude!.toDouble(),
          'longitude': coords.longitude!.toDouble(),
        });
      } else {
        completer.completeError(Exception('No se pudieron obtener las coordenadas'));
      }
    }).catchError((error) {
      String errorMessage;
      if (error is html.PositionError) {
        switch (error.code) {
          case 1:
            errorMessage = 'Acceso denegado a la ubicación. Por favor, permite el acceso en tu navegador.';
            break;
          case 2:
            errorMessage = 'Ubicación no disponible. Verifica que tengas GPS activado.';
            break;
          case 3:
            errorMessage = 'Tiempo de espera agotado. Intenta de nuevo.';
            break;
          default:
            errorMessage = 'Error desconocido al obtener ubicación.';
        }
      } else {
        errorMessage = 'Error al acceder a la ubicación: $error';
      }
      completer.completeError(Exception(errorMessage));
    });
    
    return completer.future;
  }
  
  static Future<bool> isLocationPermissionGranted() async {
    if (!kIsWeb) return false;
    
    try {
      // Intentamos obtener la ubicación para verificar permisos
      await _getCurrentPositionWeb();
      return true;
    } catch (e) {
      return false;
    }
  }
}
