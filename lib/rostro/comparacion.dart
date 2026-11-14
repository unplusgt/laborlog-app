import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Modelo de huella facial; debe coincidir con el del servidor (rostros.MODELO).
const String modeloRostro = 'sface-2021dec';
const int dimensionHuella = 128;

/// Para identificar entre todos los trabajadores (1:N) se exige más que el umbral 1:1
/// de OpenCV (0.363), y además que el segundo más parecido quede claramente atrás.
const double umbralIdentificacion = 0.42;
const double margenIdentificacion = 0.06;

Float32List normalizar(List<double> v) {
  var n = 0.0;
  for (final x in v) {
    n += x * x;
  }
  n = sqrt(n);
  if (n == 0 || n.isNaN) throw ArgumentError('Huella inválida');
  return Float32List.fromList([for (final x in v) x / n]);
}

double coseno(Float32List a, Float32List b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += a[i] * b[i];
  }
  return s;
}

/// Promedio de varias capturas del mismo rostro (registro más robusto).
Float32List promediar(List<Float32List> huellas) {
  final suma = List<double>.filled(huellas.first.length, 0);
  for (final h in huellas) {
    final hn = normalizar(h);
    for (var i = 0; i < suma.length; i++) {
      suma[i] += hn[i];
    }
  }
  return normalizar(suma);
}

/// 128 float32 little-endian en base64 (formato del servidor).
String huellaABase64(Float32List h) {
  final bd = ByteData(h.length * 4);
  for (var i = 0; i < h.length; i++) {
    bd.setFloat32(i * 4, h[i], Endian.little);
  }
  return base64Encode(bd.buffer.asUint8List());
}

Float32List huellaDeBase64(String b64) {
  final bytes = base64Decode(b64);
  if (bytes.length != dimensionHuella * 4) throw FormatException('Huella de tamaño inválido');
  final bd = ByteData.sublistView(bytes);
  return normalizar([for (var i = 0; i < dimensionHuella; i++) bd.getFloat32(i * 4, Endian.little)]);
}

class Candidato {
  final String id;
  final String nombre;
  final Float32List huella;
  Candidato(this.id, this.nombre, this.huella);
}

class Identificacion {
  final Candidato? candidato;
  final double mejor;
  final double segundo;
  Identificacion(this.candidato, this.mejor, this.segundo);

  bool get reconocido => candidato != null;
}

Identificacion identificar(
  Float32List huella,
  List<Candidato> candidatos, {
  double umbral = umbralIdentificacion,
  double margen = margenIdentificacion,
}) {
  Candidato? mejorC;
  var mejor = -1.0, segundo = -1.0;
  for (final c in candidatos) {
    final s = coseno(huella, c.huella);
    if (s > mejor) {
      segundo = mejor;
      mejor = s;
      mejorC = c;
    } else if (s > segundo) {
      segundo = s;
    }
  }
  final ok = mejorC != null && mejor >= umbral && (mejor - segundo) >= margen;
  return Identificacion(ok ? mejorC : null, mejor, segundo);
}
