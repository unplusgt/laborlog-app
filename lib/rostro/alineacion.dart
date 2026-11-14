import 'dart:math';
import 'dart:typed_data';

import 'imagen.dart';

/// Posiciones de ojos, nariz y comisuras en una cara alineada de 112x112 (plantilla
/// ArcFace, la misma que usa OpenCV FaceRecognizerSF.alignCrop). Orden: ojo izquierdo
/// en la imagen, ojo derecho, nariz, comisura izquierda, comisura derecha.
const List<Point<double>> plantilla112 = [
  Point(38.2946, 51.6963),
  Point(73.5318, 51.5014),
  Point(56.0252, 71.7366),
  Point(41.5493, 92.3655),
  Point(70.7299, 92.2041),
];

/// Tamaño del recorte que se guarda como foto y se envía al servidor. La huella se
/// calcula sobre su reducción 2x2 a 112x112 (igual que hace el servidor con INTER_AREA).
const int tamanoFoto = 224;
const int tamanoModelo = 112;

/// Transformación de similitud (rotación + escala uniforme + traslación):
///   x' = a·x − b·y + tx
///   y' = b·x + a·y + ty
class Similitud {
  final double a, b, tx, ty;
  const Similitud(this.a, this.b, this.tx, this.ty);

  Point<double> aplicar(double x, double y) => Point(a * x - b * y + tx, b * x + a * y + ty);

  Similitud inversa() {
    final d = a * a + b * b;
    final ia = a / d, ib = -b / d;
    return Similitud(ia, ib, -(ia * tx - ib * ty), -(ib * tx + ia * ty));
  }

  double get escala => sqrt(a * a + b * b);
}

/// Similitud por mínimos cuadrados que lleva [origen] a [destino] (Umeyama en 2D).
Similitud estimarSimilitud(List<Point<double>> origen, List<Point<double>> destino) {
  assert(origen.length == destino.length && origen.length >= 2);
  final n = origen.length;
  var msx = 0.0, msy = 0.0, mdx = 0.0, mdy = 0.0;
  for (var i = 0; i < n; i++) {
    msx += origen[i].x;
    msy += origen[i].y;
    mdx += destino[i].x;
    mdy += destino[i].y;
  }
  msx /= n;
  msy /= n;
  mdx /= n;
  mdy /= n;
  var num1 = 0.0, num2 = 0.0, den = 0.0;
  for (var i = 0; i < n; i++) {
    final sx = origen[i].x - msx, sy = origen[i].y - msy;
    final dx = destino[i].x - mdx, dy = destino[i].y - mdy;
    num1 += sx * dx + sy * dy;
    num2 += sx * dy - sy * dx;
    den += sx * sx + sy * sy;
  }
  if (den == 0) throw ArgumentError('Puntos degenerados');
  final a = num1 / den, b = num2 / den;
  return Similitud(a, b, mdx - (a * msx - b * msy), mdy - (b * msx + a * msy));
}

/// Ordena los 5 puntos de la cara (en coordenadas de la imagen derecha) como la
/// plantilla: por posición horizontal, sin depender de qué llama "izquierdo" cada SDK.
List<Point<double>> ordenarPuntos({
  required Point<double> ojoA,
  required Point<double> ojoB,
  required Point<double> nariz,
  required Point<double> bocaA,
  required Point<double> bocaB,
}) {
  final ojos = [ojoA, ojoB]..sort((p, q) => p.x.compareTo(q.x));
  final boca = [bocaA, bocaB]..sort((p, q) => p.x.compareTo(q.x));
  return [ojos[0], ojos[1], nariz, boca[0], boca[1]];
}

/// Recorta la cara alineada (RGB, [tamano]x[tamano]) igual que cv2.warpAffine con
/// interpolación bilineal y borde negro.
Uint8List recorteAlineado(FuenteImagen fuente, List<Point<double>> puntos, {int tamano = tamanoFoto}) {
  final k = tamano / tamanoModelo;
  final destino = [for (final p in plantilla112) Point(p.x * k, p.y * k)];
  final inv = estimarSimilitud(puntos, destino).inversa();
  final salida = Uint8List(tamano * tamano * 3);
  final rgb = List<int>.filled(3, 0);
  var i = 0;
  for (var v = 0; v < tamano; v++) {
    for (var u = 0; u < tamano; u++) {
      final p = inv.aplicar(u.toDouble(), v.toDouble());
      fuente.muestrear(p.x, p.y, rgb);
      salida[i++] = rgb[0];
      salida[i++] = rgb[1];
      salida[i++] = rgb[2];
    }
  }
  return salida;
}

/// Reduce a la mitad promediando bloques de 2x2 (equivale a INTER_AREA de OpenCV para 2x).
Uint8List reducir2x(Uint8List rgb, int tamano) {
  final m = tamano ~/ 2;
  final salida = Uint8List(m * m * 3);
  for (var y = 0; y < m; y++) {
    for (var x = 0; x < m; x++) {
      final i00 = ((2 * y) * tamano + 2 * x) * 3;
      final i01 = i00 + 3;
      final i10 = i00 + tamano * 3;
      final i11 = i10 + 3;
      final o = (y * m + x) * 3;
      for (var c = 0; c < 3; c++) {
        salida[o + c] = ((rgb[i00 + c] + rgb[i01 + c] + rgb[i10 + c] + rgb[i11 + c] + 2) >> 2);
      }
    }
  }
  return salida;
}

/// Entrada del modelo SFace: 1x3x112x112, canales R,G,B, valores 0..255 (igual que
/// cv2.dnn.blobFromImage(img, 1, (112,112), 0, swapRB=True)).
Float32List tensorModelo(Uint8List rgb112) {
  const n = tamanoModelo * tamanoModelo;
  final t = Float32List(3 * n);
  for (var i = 0; i < n; i++) {
    t[i] = rgb112[i * 3].toDouble();
    t[n + i] = rgb112[i * 3 + 1].toDouble();
    t[2 * n + i] = rgb112[i * 3 + 2].toDouble();
  }
  return t;
}
