import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'alineacion.dart';
import 'comparacion.dart';
import 'imagen.dart';

/// Modelo SFace (OpenCV Zoo, Apache 2.0). No va en git: lo descarga
/// tool/descargar_modelo.sh (y GitHub Actions al compilar el APK).
const String assetModelo = 'assets/modelos/face_recognition_sface_2021dec.onnx';

/// Resultado de capturar un rostro: su huella, la foto alineada (evidencia) y la
/// prueba de vida superada.
class CapturaRostro {
  final Float32List huella;
  final Uint8List jpeg;
  final String pruebaVida;
  final DateTime en;

  CapturaRostro(this.huella, this.jpeg, this.pruebaVida) : en = DateTime.now();
}

class ModeloNoDisponible implements Exception {
  final String message;
  ModeloNoDisponible(this.message);
  @override
  String toString() => message;
}

/// Detección de caras (ML Kit, en el teléfono) + huella facial (SFace con ONNX Runtime).
/// Todo funciona sin internet.
class ServicioRostro {
  final FaceDetector _detector;
  final OrtSession _sesion;
  final String _entrada;

  ServicioRostro._(this._detector, this._sesion, this._entrada);

  static Future<ServicioRostro>? _cargando;

  static Future<ServicioRostro> obtener() => _cargando ??= _crear().catchError((Object e) {
        _cargando = null;
        throw e;
      });

  static Future<ServicioRostro> _crear() async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true, // ojos abiertos (parpadeo)
        enableLandmarks: true, // ojos, nariz, boca (alineación)
        enableTracking: true, // misma cara durante la prueba de vida
        minFaceSize: 0.2,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    final OrtSession sesion;
    try {
      sesion = await OnnxRuntime().createSessionFromAsset(assetModelo);
    } catch (e) {
      await detector.close();
      throw ModeloNoDisponible('No se pudo cargar el modelo facial ($e)');
    }
    return ServicioRostro._(detector, sesion, sesion.inputNames.first);
  }

  static const _orientaciones = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Rotación que hay que aplicar al cuadro para verlo derecho (como en el ejemplo
  /// oficial de google_mlkit).
  static int rotacion(CameraDescription camara, DeviceOrientation orientacion) {
    if (Platform.isIOS) return camara.sensorOrientation;
    final comp = _orientaciones[orientacion] ?? 0;
    if (camara.lensDirection == CameraLensDirection.front) {
      return (camara.sensorOrientation + comp) % 360;
    }
    return (camara.sensorOrientation - comp + 360) % 360;
  }

  Future<List<Face>> detectar(CameraImage imagen, int rotacionGrados) async {
    final rot = InputImageRotationValue.fromRawValue(rotacionGrados) ?? InputImageRotation.rotation0deg;
    final plano = imagen.planes.first;
    final entrada = InputImage.fromBytes(
      bytes: plano.bytes,
      metadata: InputImageMetadata(
        size: Size(imagen.width.toDouble(), imagen.height.toDouble()),
        rotation: rot,
        format: Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21,
        bytesPerRow: plano.bytesPerRow,
      ),
    );
    return _detector.processImage(entrada);
  }

  /// Ancho de la imagen ya girada (para saber qué tan cerca está la cara).
  static double anchoDerecho(CameraImage imagen, int rotacionGrados) =>
      (rotacionGrados % 180 == 0 ? imagen.width : imagen.height).toDouble();

  /// Recorta y alinea la cara, calcula su huella y codifica la foto. Devuelve null si
  /// ML Kit no dio los 5 puntos necesarios en este cuadro.
  Future<CapturaRostro?> extraer(CameraImage imagen, int rotacionGrados, Face cara, String pruebaVida) async {
    Point<double>? punto(FaceLandmarkType t) {
      final p = cara.landmarks[t]?.position;
      return p == null ? null : Point(p.x.toDouble(), p.y.toDouble());
    }

    final ojoA = punto(FaceLandmarkType.leftEye), ojoB = punto(FaceLandmarkType.rightEye);
    final nariz = punto(FaceLandmarkType.noseBase);
    final bocaA = punto(FaceLandmarkType.leftMouth), bocaB = punto(FaceLandmarkType.rightMouth);
    if (ojoA == null || ojoB == null || nariz == null || bocaA == null || bocaB == null) return null;

    final plano = imagen.planes.first;
    final FuenteImagen fuente = Platform.isIOS
        ? FuenteBgra(plano.bytes, imagen.width, imagen.height, bytesPorFila: plano.bytesPerRow)
        : FuenteNv21(plano.bytes, imagen.width, imagen.height, rotacionGrados, bytesPorFila: plano.bytesPerRow);
    final puntos = ordenarPuntos(ojoA: ojoA, ojoB: ojoB, nariz: nariz, bocaA: bocaA, bocaB: bocaB);

    final rgb224 = recorteAlineado(fuente, puntos, tamano: tamanoFoto);
    final huella = await huellaDe(reducir2x(rgb224, tamanoFoto));
    final jpeg = img.encodeJpg(
      img.Image.fromBytes(width: tamanoFoto, height: tamanoFoto, bytes: rgb224.buffer, numChannels: 3),
      quality: 88,
    );
    return CapturaRostro(huella, jpeg, pruebaVida);
  }

  Future<Float32List> huellaDe(Uint8List rgb112) async {
    final entrada = await OrtValue.fromList(tensorModelo(rgb112), [1, 3, tamanoModelo, tamanoModelo]);
    try {
      final salidas = await _sesion.run({_entrada: entrada});
      try {
        final valores = await salidas.values.first.asFlattenedList();
        return normalizar([for (final v in valores) (v as num).toDouble()]);
      } finally {
        for (final s in salidas.values) {
          await s.dispose();
        }
      }
    } finally {
      await entrada.dispose();
    }
  }
}
