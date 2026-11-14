import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'prueba_vida.dart';
import 'servicio_rostro.dart';

/// Pantalla de cámara: guía a la persona, hace la prueba de vida y devuelve
/// [capturas] capturas de su rostro (1 para marcar, varias para registrar).
class EscanerRostroScreen extends StatefulWidget {
  final String titulo;
  final int capturas;

  const EscanerRostroScreen({super.key, required this.titulo, this.capturas = 1});

  /// Abre la cámara y devuelve las capturas, o null si se canceló.
  static Future<List<CapturaRostro>?> abrir(BuildContext context, {required String titulo, int capturas = 1}) {
    return Navigator.push<List<CapturaRostro>>(
      context,
      MaterialPageRoute(builder: (_) => EscanerRostroScreen(titulo: titulo, capturas: capturas)),
    );
  }

  @override
  State<EscanerRostroScreen> createState() => _EscanerRostroScreenState();
}

class _EscanerRostroScreenState extends State<EscanerRostroScreen> {
  static const _entreCapturas = Duration(milliseconds: 300);

  CameraController? _camara;
  ServicioRostro? _servicio;
  PruebaVida _vida = PruebaVida();
  String _mensaje = 'Preparando la cámara…';
  String? _error;
  bool _procesando = false;
  bool _terminado = false;
  final List<CapturaRostro> _capturas = [];
  DateTime _ultimaCaptura = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    if (kIsWeb) {
      setState(() => _error = 'El reconocimiento facial solo funciona en la app del celular.');
      return;
    }
    try {
      final camaras = await availableCameras();
      if (camaras.isEmpty) throw CameraException('sin_camara', 'Este teléfono no tiene cámara');
      final frontal = camaras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => camaras.first,
      );
      final control = CameraController(
        frontal,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      await control.initialize();
      final servicio = await ServicioRostro.obtener();
      if (!mounted) {
        await control.dispose();
        return;
      }
      setState(() {
        _camara = control;
        _servicio = servicio;
        _mensaje = 'Mira a la cámara';
      });
      await control.startImageStream(_procesarCuadro);
    } on CameraException catch (e) {
      setState(() => _error = e.code == 'CameraAccessDenied' || e.code.contains('Permission')
          ? 'Se necesita permiso de cámara. Habilítalo en Ajustes > Aplicaciones > LaborLog.'
          : 'No se pudo abrir la cámara: ${e.description ?? e.code}');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _procesarCuadro(CameraImage imagen) async {
    final camara = _camara, servicio = _servicio;
    if (_procesando || _terminado || camara == null || servicio == null) return;
    _procesando = true;
    try {
      final rot = ServicioRostro.rotacion(camara.description, camara.value.deviceOrientation);
      final caras = await servicio.detectar(imagen, rot);
      final Face? cara = caras.length == 1 ? caras.first : null;
      final lectura = cara == null
          ? LecturaCara(caras: caras.length)
          : LecturaCara(
              caras: 1,
              trackingId: cara.trackingId,
              ojoIzq: cara.leftEyeOpenProbability,
              ojoDer: cara.rightEyeOpenProbability,
              yaw: cara.headEulerAngleY,
              pitch: cara.headEulerAngleX,
              anchoRelativo: cara.boundingBox.width / ServicioRostro.anchoDerecho(imagen, rot),
            );
      final estado = _vida.procesar(lectura);

      if (estado.fase == FaseVida.listo && cara != null) {
        final deFrente = (cara.headEulerAngleY ?? 99).abs() < PruebaVida.yawFrente &&
            (cara.leftEyeOpenProbability ?? 0) > PruebaVida.ojoAbierto &&
            (cara.rightEyeOpenProbability ?? 0) > PruebaVida.ojoAbierto;
        if (deFrente && DateTime.now().difference(_ultimaCaptura) > _entreCapturas) {
          final captura = await servicio.extraer(imagen, rot, cara, _vida.nombreReto);
          if (captura != null) {
            _capturas.add(captura);
            _ultimaCaptura = DateTime.now();
          }
        }
        if (_capturas.length >= widget.capturas) {
          _terminado = true;
          await camara.stopImageStream();
          if (mounted) Navigator.pop(context, List<CapturaRostro>.from(_capturas));
          return;
        }
        _actualizar(widget.capturas > 1
            ? 'Quédate quieto mirando la cámara (${_capturas.length}/${widget.capturas})'
            : 'Quédate quieto');
      } else {
        _actualizar(estado.mensaje);
      }
    } catch (e) {
      _actualizar('Error: $e');
    } finally {
      _procesando = false;
    }
  }

  void _actualizar(String mensaje) {
    if (mounted && mensaje != _mensaje) setState(() => _mensaje = mensaje);
  }

  void _reintentar() {
    setState(() {
      _vida = PruebaVida();
      _capturas.clear();
      _mensaje = 'Mira a la cámara';
    });
  }

  @override
  void dispose() {
    final c = _camara;
    _camara = null;
    if (c != null) {
      if (c.value.isStreamingImages) {
        c.stopImageStream().whenComplete(c.dispose);
      } else {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camara = _camara;
    final fallido = _vida.fase == FaseVida.fallido;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                if (camara != null && camara.value.isInitialized)
                  Center(child: CameraPreview(camara))
                else
                  const Center(child: CircularProgressIndicator()),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 260,
                      height: 340,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 3),
                        borderRadius: const BorderRadius.all(Radius.elliptical(130, 170)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 32,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _mensaje,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (fallido) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _reintentar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Intentar de nuevo'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
