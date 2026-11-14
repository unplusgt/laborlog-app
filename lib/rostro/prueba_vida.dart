import 'dart:math';

/// Lo que ML Kit dice de las caras en un cuadro de la cámara.
class LecturaCara {
  final int caras;
  final int? trackingId;
  final double? ojoIzq;
  final double? ojoDer;
  final double? yaw; // giro izquierda/derecha (grados)
  final double? pitch; // arriba/abajo (grados)
  /// Ancho de la cara / ancho de la imagen
  final double anchoRelativo;

  const LecturaCara({
    required this.caras,
    this.trackingId,
    this.ojoIzq,
    this.ojoDer,
    this.yaw,
    this.pitch,
    this.anchoRelativo = 0,
  });

  static const ninguna = LecturaCara(caras: 0);
}

enum Reto { parpadeo, giro }

enum FaseVida { buscando, reto, listo, fallido }

class EstadoVida {
  final FaseVida fase;
  final String mensaje;
  const EstadoVida(this.fase, this.mensaje);
}

/// Prueba de vida simple: con la cara de frente, la persona debe parpadear o girar la
/// cabeza (al azar) y volver al frente, sin que se pierda el seguimiento de la cara.
/// Dificulta marcar con una foto impresa o una foto fija en otra pantalla.
class PruebaVida {
  static const double anchoMinimo = 0.25;
  static const double yawFrente = 12;
  static const double pitchFrente = 15;
  static const double yawGiro = 22;
  static const double ojoAbierto = 0.6;
  static const double ojoCerrado = 0.3;

  final Duration limite;
  final DateTime Function() _reloj;
  final Random _rnd;

  final Reto? _retoFijo;
  late Reto reto;
  FaseVida _fase = FaseVida.buscando;
  int? _tracking;
  DateTime? _inicio;
  bool _paso1 = false; // ojos cerrados / cabeza girada
  bool _completado = false;

  PruebaVida({Reto? reto, Random? rnd, this.limite = const Duration(seconds: 12), DateTime Function()? reloj})
      : _retoFijo = reto,
        _rnd = rnd ?? Random(),
        _reloj = reloj ?? DateTime.now {
    _elegirReto();
  }

  FaseVida get fase => _fase;

  /// Nombre de la prueba superada (se guarda en el marcaje).
  String get nombreReto => reto == Reto.parpadeo ? 'parpadeo' : 'giro';

  void _elegirReto() => reto = _retoFijo ?? (_rnd.nextBool() ? Reto.parpadeo : Reto.giro);

  void reiniciar() {
    _fase = FaseVida.buscando;
    _tracking = null;
    _inicio = null;
    _paso1 = false;
    _completado = false;
    _elegirReto();
  }

  String get _instruccion => reto == Reto.parpadeo
      ? 'Parpadea despacio'
      : 'Gira la cabeza hacia un lado y vuelve al frente';

  bool _deFrente(LecturaCara l) =>
      l.yaw != null && l.yaw!.abs() < yawFrente && (l.pitch == null || l.pitch!.abs() < pitchFrente);

  bool _ojosAbiertos(LecturaCara l) =>
      (l.ojoIzq ?? 0) > ojoAbierto && (l.ojoDer ?? 0) > ojoAbierto;

  EstadoVida procesar(LecturaCara l) {
    if (_fase == FaseVida.fallido || _fase == FaseVida.listo) {
      return EstadoVida(_fase, _fase == FaseVida.listo ? 'Listo' : 'No se completó la prueba');
    }
    if (_inicio != null && _reloj().difference(_inicio!) > limite) {
      _fase = FaseVida.fallido;
      return const EstadoVida(FaseVida.fallido, 'No se completó la prueba. Intenta de nuevo.');
    }
    if (l.caras == 0) {
      if (_fase == FaseVida.reto) _reiniciarSeguimiento();
      return const EstadoVida(FaseVida.buscando, 'Mira a la cámara');
    }
    if (l.caras > 1) {
      _reiniciarSeguimiento();
      return const EstadoVida(FaseVida.buscando, 'Solo una persona frente a la cámara');
    }
    if (l.anchoRelativo < anchoMinimo) {
      return const EstadoVida(FaseVida.buscando, 'Acércate más a la cámara');
    }

    switch (_fase) {
      case FaseVida.buscando:
        if (!_deFrente(l) || !_ojosAbiertos(l)) {
          return const EstadoVida(FaseVida.buscando, 'Mira de frente a la cámara');
        }
        _fase = FaseVida.reto;
        _tracking = l.trackingId;
        _inicio ??= _reloj();
        _paso1 = false;
        _completado = false;
        return EstadoVida(FaseVida.reto, _instruccion);

      case FaseVida.reto:
        if (_tracking != null && l.trackingId != null && l.trackingId != _tracking) {
          _reiniciarSeguimiento();
          return const EstadoVida(FaseVida.buscando, 'Mantente frente a la cámara');
        }
        if (!_completado) {
          if (reto == Reto.parpadeo) {
            final izq = l.ojoIzq, der = l.ojoDer;
            if (izq != null && der != null) {
              if (!_paso1 && izq < ojoCerrado && der < ojoCerrado) _paso1 = true;
              if (_paso1 && izq > ojoAbierto && der > ojoAbierto) _completado = true;
            }
          } else {
            final yaw = l.yaw;
            if (yaw != null) {
              if (!_paso1 && yaw.abs() > yawGiro) _paso1 = true;
              if (_paso1 && yaw.abs() < yawFrente) _completado = true;
            }
          }
        }
        if (_completado && _deFrente(l) && _ojosAbiertos(l)) {
          _fase = FaseVida.listo;
          return const EstadoVida(FaseVida.listo, 'Listo');
        }
        return EstadoVida(FaseVida.reto, _completado ? 'Mira de frente a la cámara' : _instruccion);

      case FaseVida.listo:
      case FaseVida.fallido:
        return EstadoVida(_fase, '');
    }
  }

  void _reiniciarSeguimiento() {
    _fase = FaseVida.buscando;
    _tracking = null;
    _paso1 = false;
    _completado = false;
  }
}
