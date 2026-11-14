import 'dart:math';

/// Distancia en metros entre dos coordenadas (fórmula de Haversine).
/// Es la misma que usa el servidor (laborlog_backend/marcajes.py).
double distanciaMetros(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final p1 = lat1 * pi / 180;
  final p2 = lat2 * pi / 180;
  final dp = (lat2 - lat1) * pi / 180;
  final dl = (lng2 - lng1) * pi / 180;
  final a = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2);
  return 2 * r * atan2(sqrt(a), sqrt(1 - a));
}
