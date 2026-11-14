import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:laborlog_app/rostro/alineacion.dart';
import 'package:laborlog_app/rostro/comparacion.dart';
import 'package:laborlog_app/rostro/imagen.dart';
import 'package:laborlog_app/rostro/prueba_vida.dart';

Float32List _vector(int semilla) {
  final r = Random(semilla);
  return normalizar([for (var i = 0; i < 128; i++) r.nextDouble() - 0.5]);
}

void main() {
  group('alineación', () {
    test('la similitud estimada lleva los puntos de la plantilla a sí mismos', () {
      final t = estimarSimilitud(plantilla112, plantilla112);
      expect(t.a, closeTo(1, 1e-9));
      expect(t.b, closeTo(0, 1e-9));
      expect(t.tx, closeTo(0, 1e-9));
    });

    test('recupera una rotación + escala + traslación conocida y su inversa', () {
      const real = Similitud(0.8, 0.3, 12, -7);
      final origen = [for (final p in plantilla112) p];
      final destino = [for (final p in origen) real.aplicar(p.x, p.y)];
      final t = estimarSimilitud(origen, destino);
      expect(t.a, closeTo(0.8, 1e-9));
      expect(t.b, closeTo(0.3, 1e-9));
      final ida = t.aplicar(10, 20);
      final vuelta = t.inversa().aplicar(ida.x, ida.y);
      expect(vuelta.x, closeTo(10, 1e-9));
      expect(vuelta.y, closeTo(20, 1e-9));
    });

    test('ordena ojos y comisuras por posición horizontal', () {
      final p = ordenarPuntos(
        ojoA: const Point(120, 55),
        ojoB: const Point(70, 60),
        nariz: const Point(97, 85),
        bocaA: const Point(118, 106),
        bocaB: const Point(75, 110),
      );
      expect(p.map((e) => e.x).toList(), [70, 120, 97, 75, 118]);
    });

    test('el recorte coincide con OpenCV alignCrop (lo que hace el servidor)', () {
      final imagen = File('test/fixtures/imagen_200x160.rgb').readAsBytesSync();
      final referencia = File('test/fixtures/recorte_opencv_112.rgb').readAsBytesSync();
      final fuente = FuenteRgb(200, 160, imagen);
      const puntos = [Point(70.0, 60.0), Point(120.0, 55.0), Point(97.0, 85.0), Point(75.0, 110.0), Point(118.0, 106.0)];
      final recorte = recorteAlineado(fuente, puntos, tamano: 112);
      var suma = 0, maximo = 0;
      for (var i = 0; i < recorte.length; i++) {
        final d = (recorte[i] - referencia[i]).abs();
        suma += d;
        maximo = max(maximo, d);
      }
      expect(suma / recorte.length, lessThan(1.0), reason: 'diferencia media');
      expect(maximo, lessThanOrEqualTo(3), reason: 'diferencia máxima');
    });

    test('reducir2x promedia bloques de 2x2', () {
      final rgb = Uint8List.fromList([
        0, 0, 0, 4, 4, 4, //
        8, 8, 8, 12, 12, 12,
      ]);
      expect(reducir2x(rgb, 2), [6, 6, 6]);
    });

    test('tensor del modelo en orden NCHW con canales R, G, B', () {
      final rgb = Uint8List(112 * 112 * 3);
      rgb[0] = 10;
      rgb[1] = 20;
      rgb[2] = 30;
      final t = tensorModelo(rgb);
      expect(t.length, 3 * 112 * 112);
      expect([t[0], t[112 * 112], t[2 * 112 * 112]], [10, 20, 30]);
    });
  });

  group('imagen NV21 de la cámara', () {
    // Imagen cruda 4x2: Y = índice*10; VU neutro (gris)
    Uint8List nv21() {
      final y = [for (var i = 0; i < 8; i++) i * 10];
      return Uint8List.fromList([...y, 128, 128, 128, 128]);
    }

    test('sin rotación lee la luminancia como gris', () {
      final f = FuenteNv21(nv21(), 4, 2, 0);
      final rgb = [0, 0, 0];
      f.muestrear(2, 1, rgb);
      expect(rgb, [60, 60, 60]);
    });

    test('rotación 270 (cámara frontal en vertical) mapea coordenadas', () {
      final f = FuenteNv21(nv21(), 4, 2, 270);
      expect(f.ancho, 2);
      expect(f.alto, 4);
      final rgb = [0, 0, 0];
      // Derecha (x=0, y=0) ↔ crudo (x=3, y=0) → Y = 30
      f.muestrear(0, 0, rgb);
      expect(rgb[0], 30);
      // Derecha (x=1, y=3) ↔ crudo (x=0, y=1) → Y = 40
      f.muestrear(1, 3, rgb);
      expect(rgb[0], 40);
    });

    test('rotación 90 mapea coordenadas', () {
      final f = FuenteNv21(nv21(), 4, 2, 90);
      final rgb = [0, 0, 0];
      // Derecha (x=0, y=0) ↔ crudo (x=0, y=1) → Y = 40
      f.muestrear(0, 0, rgb);
      expect(rgb[0], 40);
    });

    test('color: V alto es rojizo', () {
      final b = nv21();
      b[8] = 200; // V
      final f = FuenteNv21(b, 4, 2, 0);
      final rgb = [0, 0, 0];
      f.muestrear(0, 0, rgb);
      expect(rgb[0], greaterThan(rgb[2]));
    });

    test('fuera de la imagen es negro', () {
      final rgb = [1, 1, 1];
      FuenteNv21(nv21(), 4, 2, 0).muestrear(-5, 0, rgb);
      expect(rgb, [0, 0, 0]);
    });
  });

  group('comparación de huellas', () {
    test('base64 ida y vuelta (formato del servidor)', () {
      final h = _vector(1);
      final h2 = huellaDeBase64(huellaABase64(h));
      expect(coseno(h, h2), closeTo(1, 1e-6));
    });

    test('identifica al más parecido si supera el umbral y el margen', () {
      final juan = _vector(1), maria = _vector(2);
      final c = [Candidato('j', 'Juan', juan), Candidato('m', 'María', maria)];
      final r = identificar(juan, c);
      expect(r.reconocido, isTrue);
      expect(r.candidato!.nombre, 'Juan');
      expect(r.mejor, closeTo(1, 1e-6));
    });

    test('no reconoce a un desconocido', () {
      final c = [Candidato('j', 'Juan', _vector(1)), Candidato('m', 'María', _vector(2))];
      expect(identificar(_vector(3), c).reconocido, isFalse);
    });

    test('no decide si dos trabajadores se parecen demasiado (margen)', () {
      final juan = _vector(1);
      final gemelo = normalizar([for (var i = 0; i < 128; i++) juan[i] + (i == 0 ? 0.01 : 0)]);
      final r = identificar(juan, [Candidato('j', 'Juan', juan), Candidato('g', 'Gemelo', gemelo)]);
      expect(r.reconocido, isFalse);
    });

    test('promediar capturas da una huella normalizada', () {
      final p = promediar([_vector(1), _vector(1), _vector(1)]);
      expect(coseno(p, _vector(1)), closeTo(1, 1e-6));
    });
  });

  group('prueba de vida', () {
    const frente = LecturaCara(caras: 1, trackingId: 7, ojoIzq: 0.95, ojoDer: 0.95, yaw: 2, pitch: 1, anchoRelativo: 0.4);
    LecturaCara con({double? yaw, double? ojos, int tracking = 7, int caras = 1, double ancho = 0.4}) => LecturaCara(
          caras: caras,
          trackingId: tracking,
          ojoIzq: ojos ?? 0.95,
          ojoDer: ojos ?? 0.95,
          yaw: yaw ?? 2,
          pitch: 1,
          anchoRelativo: ancho,
        );

    test('parpadeo completo', () {
      final v = PruebaVida(reto: Reto.parpadeo);
      expect(v.procesar(frente).fase, FaseVida.reto);
      expect(v.procesar(con(ojos: 0.1)).fase, FaseVida.reto);
      expect(v.procesar(frente).fase, FaseVida.listo);
      expect(v.nombreReto, 'parpadeo');
    });

    test('foto fija (ojos siempre abiertos) no pasa', () {
      final v = PruebaVida(reto: Reto.parpadeo);
      for (var i = 0; i < 50; i++) {
        expect(v.procesar(frente).fase, isNot(FaseVida.listo));
      }
    });

    test('giro de cabeza y regreso al frente', () {
      final v = PruebaVida(reto: Reto.giro);
      v.procesar(frente);
      expect(v.procesar(con(yaw: 30)).fase, FaseVida.reto);
      expect(v.procesar(frente).fase, FaseVida.listo);
    });

    test('si cambia la cara (otro trackingId) vuelve a empezar', () {
      final v = PruebaVida(reto: Reto.parpadeo);
      v.procesar(frente);
      v.procesar(con(ojos: 0.1));
      expect(v.procesar(con(tracking: 99)).fase, FaseVida.buscando);
      expect(v.procesar(con(tracking: 99)).fase, FaseVida.reto);
      expect(v.procesar(con(tracking: 99)).fase, FaseVida.reto, reason: 'falta parpadear de nuevo');
    });

    test('dos caras o cara lejana no avanzan', () {
      final v = PruebaVida(reto: Reto.parpadeo);
      expect(v.procesar(con(caras: 2)).mensaje, contains('Solo una persona'));
      expect(v.procesar(con(ancho: 0.1)).mensaje, contains('Acércate'));
    });

    test('se agota el tiempo', () {
      var ahora = DateTime(2026);
      final v = PruebaVida(reto: Reto.giro, reloj: () => ahora);
      v.procesar(frente);
      ahora = ahora.add(const Duration(seconds: 30));
      expect(v.procesar(frente).fase, FaseVida.fallido);
    });
  });
}
