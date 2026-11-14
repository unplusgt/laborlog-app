import 'dart:typed_data';

/// Imagen de la que se pueden leer colores en coordenadas de la imagen "derecha"
/// (la orientación en la que ML Kit entrega la posición de la cara).
abstract class FuenteImagen {
  int get ancho;
  int get alto;

  /// Escribe en [rgb] el color en (x, y) con interpolación bilineal; fuera de la
  /// imagen devuelve negro.
  void muestrear(double x, double y, List<int> rgb);
}

/// Imagen RGB en memoria (pruebas y fotos ya convertidas).
class FuenteRgb implements FuenteImagen {
  @override
  final int ancho;
  @override
  final int alto;
  final Uint8List datos; // RGB, fila por fila

  FuenteRgb(this.ancho, this.alto, this.datos);

  @override
  void muestrear(double x, double y, List<int> rgb) {
    final x0 = x.floor(), y0 = y.floor();
    final fx = x - x0, fy = y - y0;
    for (var c = 0; c < 3; c++) {
      final v = _px(x0, y0, c) * (1 - fx) * (1 - fy) +
          _px(x0 + 1, y0, c) * fx * (1 - fy) +
          _px(x0, y0 + 1, c) * (1 - fx) * fy +
          _px(x0 + 1, y0 + 1, c) * fx * fy;
      rgb[c] = v.round().clamp(0, 255);
    }
  }

  double _px(int x, int y, int c) {
    if (x < 0 || y < 0 || x >= ancho || y >= alto) return 0;
    return datos[(y * ancho + x) * 3 + c].toDouble();
  }
}

/// Cuadro de la cámara de Android en NV21 (Y completo + VU intercalado a media
/// resolución), tal como lo entrega el plugin camera con ImageFormatGroup.nv21.
///
/// [rotacion] es la que se le pasa a ML Kit (0, 90, 180, 270): las coordenadas que se
/// piden son las de la imagen ya girada a la posición correcta.
class FuenteNv21 implements FuenteImagen {
  final Uint8List bytes;
  final int anchoCrudo;
  final int altoCrudo;
  final int filaBytes;
  final int rotacion;

  FuenteNv21(this.bytes, this.anchoCrudo, this.altoCrudo, this.rotacion, {int? bytesPorFila})
      : filaBytes = bytesPorFila ?? anchoCrudo {
    if (![0, 90, 180, 270].contains(rotacion)) throw ArgumentError('rotacion inválida');
  }

  @override
  int get ancho => rotacion % 180 == 0 ? anchoCrudo : altoCrudo;
  @override
  int get alto => rotacion % 180 == 0 ? altoCrudo : anchoCrudo;

  /// Coordenada de la imagen derecha → coordenada en el búfer de la cámara.
  (double, double) aCrudo(double x, double y) {
    switch (rotacion) {
      case 90:
        return (y, altoCrudo - 1 - x);
      case 180:
        return (anchoCrudo - 1 - x, altoCrudo - 1 - y);
      case 270:
        return (anchoCrudo - 1 - y, x);
      default:
        return (x, y);
    }
  }

  @override
  void muestrear(double x, double y, List<int> rgb) {
    final (xr, yr) = aCrudo(x, y);
    if (xr < 0 || yr < 0 || xr > anchoCrudo - 1 || yr > altoCrudo - 1) {
      rgb[0] = rgb[1] = rgb[2] = 0;
      return;
    }
    final x0 = xr.floor(), y0 = yr.floor();
    final x1 = x0 + 1 < anchoCrudo ? x0 + 1 : x0;
    final y1 = y0 + 1 < altoCrudo ? y0 + 1 : y0;
    final fx = xr - x0, fy = yr - y0;
    final luz = bytes[y0 * filaBytes + x0] * (1 - fx) * (1 - fy) +
        bytes[y0 * filaBytes + x1] * fx * (1 - fy) +
        bytes[y1 * filaBytes + x0] * (1 - fx) * fy +
        bytes[y1 * filaBytes + x1] * fx * fy;
    final iuv = filaBytes * altoCrudo + (yr.round() ~/ 2).clamp(0, altoCrudo ~/ 2 - 1) * filaBytes +
        (xr.round() ~/ 2).clamp(0, anchoCrudo ~/ 2 - 1) * 2;
    final v = bytes[iuv] - 128.0;
    final u = bytes[iuv + 1] - 128.0;
    rgb[0] = (luz + 1.402 * v).round().clamp(0, 255);
    rgb[1] = (luz - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
    rgb[2] = (luz + 1.772 * u).round().clamp(0, 255);
  }
}

/// Cuadro BGRA (cámara de iOS).
class FuenteBgra implements FuenteImagen {
  final Uint8List bytes;
  @override
  final int ancho;
  @override
  final int alto;
  final int filaBytes;

  FuenteBgra(this.bytes, this.ancho, this.alto, {int? bytesPorFila}) : filaBytes = bytesPorFila ?? ancho * 4;

  @override
  void muestrear(double x, double y, List<int> rgb) {
    final xi = x.round(), yi = y.round();
    if (xi < 0 || yi < 0 || xi >= ancho || yi >= alto) {
      rgb[0] = rgb[1] = rgb[2] = 0;
      return;
    }
    final i = yi * filaBytes + xi * 4;
    rgb[0] = bytes[i + 2];
    rgb[1] = bytes[i + 1];
    rgb[2] = bytes[i];
  }
}
