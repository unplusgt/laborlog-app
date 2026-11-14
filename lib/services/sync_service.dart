import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/kiosco.dart';
import '../utils/app_config.dart';
import '../utils/reglas_marcaje.dart';
import 'almacen.dart';

/// El servidor rechazó el token del dispositivo (inválido, rotado o desactivado).
class DispositivoNoAutorizado implements Exception {
  final String message;
  DispositivoNoAutorizado(this.message);
  @override
  String toString() => message;
}

/// No se pudo contactar al servidor (sin señal, servidor caído, URL mala).
class SinConexion implements Exception {
  final String message;
  SinConexion([this.message = 'Sin conexión con el servidor']);
  @override
  String toString() => message;
}

class ResultadoSync {
  final int aceptados;
  final List<MarcajePendiente> rechazados;
  final int pendientes;
  final bool sinConexion;

  ResultadoSync({
    this.aceptados = 0,
    this.rechazados = const [],
    this.pendientes = 0,
    this.sinConexion = false,
  });
}

/// Modo kiosco: un teléfono instalado en una obra, autenticado con su token
/// (header X-Device-Token). Los marcajes se guardan primero en el teléfono y se
/// envían en lotes a POST /marcajes/lote cuando hay conexión.
class KioscoService {
  static const claveToken = 'kiosco_device_token';
  static const claveConfig = 'kiosco_config';
  static const claveCola = 'kiosco_cola';
  static const claveUltimos = 'kiosco_ultimos';

  /// Cada marcaje facial lleva su foto (~20 KB): lotes pequeños.
  static const int tamanoLote = 20;
  static const Duration timeout = Duration(seconds: 20);
  static const Duration refrescoConfig = Duration(minutes: 15);

  final AlmacenClaveValor _almacen;
  final AlmacenClaveValor _seguro;
  final AlmacenFotos _fotos;
  final http.Client _http;
  final DateTime Function() _reloj;
  final String Function() _apiUrl;

  KioscoService({
    required AlmacenClaveValor almacen,
    required AlmacenClaveValor almacenSeguro,
    AlmacenFotos? fotos,
    http.Client? client,
    DateTime Function()? reloj,
    String Function()? apiUrl,
  })  : _almacen = almacen,
        _seguro = almacenSeguro,
        _fotos = fotos ?? AlmacenFotosMemoria(),
        _http = client ?? http.Client(),
        _reloj = reloj ?? DateTime.now,
        _apiUrl = apiUrl ?? (() => AppConfig.apiUrl);

  static KioscoService? _instancia;

  /// Instancia de la app (almacenes reales).
  static KioscoService get instancia => _instancia ??= KioscoService(
        almacen: AlmacenPreferencias(),
        almacenSeguro: AlmacenSeguro(),
        fotos: AlmacenFotosArchivos(),
      );

  // ---------------------------------------------------------------- exclusión
  // La cola se lee y escribe completa; esto evita que un marcaje nuevo se pierda
  // si llega mientras se procesa la respuesta de una sincronización.
  Future<void> _cerrojo = Future.value();

  Future<T> _exclusivo<T>(Future<T> Function() accion) {
    final completer = Completer<T>();
    final anterior = _cerrojo;
    _cerrojo = completer.future.then((_) {}, onError: (_) {});
    anterior.whenComplete(() async {
      try {
        completer.complete(await accion());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  // ------------------------------------------------------------ activación
  Future<bool> estaActivado() async => (await _seguro.leer(claveToken)) != null;

  /// Valida el token contra el servidor y, si es correcto, lo guarda.
  Future<KioscoConfig> activar(String token) async {
    final config = await _descargarConfig(token.trim());
    await _seguro.escribir(claveToken, token.trim());
    await _guardarConfig(config);
    return config;
  }

  /// Borra token, configuración y cola (incluidos marcajes sin enviar).
  Future<void> desactivar() async {
    await _seguro.borrar(claveToken);
    await _almacen.borrar(claveConfig);
    await _almacen.borrar(claveCola);
    await _almacen.borrar(claveUltimos);
    await _fotos.borrarTodas();
  }

  /// Guarda la foto de un marcaje antes de encolarlo; devuelve su referencia.
  Future<String> guardarFoto(String marcajeId, Uint8List jpeg) => _fotos.guardar(marcajeId, jpeg);

  Future<Uint8List?> leerFoto(String ref) => _fotos.leer(ref);

  // ------------------------------------------------------------ configuración
  Future<KioscoConfig?> configGuardada() async {
    final raw = await _almacen.leer(claveConfig);
    if (raw == null) return null;
    return KioscoConfig.fromJson(json.decode(raw));
  }

  /// Descarga obra y trabajadores. Lanza SinConexion o DispositivoNoAutorizado.
  Future<KioscoConfig> actualizarConfig() async {
    final token = await _token();
    final config = await _descargarConfig(token);
    await _guardarConfig(config);
    return config;
  }

  Future<KioscoConfig> _descargarConfig(String token) async {
    final r = await _enviar(() => _http.get(
          Uri.parse('${_apiUrl()}/kiosco/config'),
          headers: {'X-Device-Token': token},
        ));
    final body = json.decode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    body['descargada_en'] = _reloj().toUtc().toIso8601String();
    return KioscoConfig.fromJson(body);
  }

  Future<void> _guardarConfig(KioscoConfig config) =>
      _almacen.escribir(claveConfig, json.encode(config.toJson()));

  Future<String> _token() async {
    final token = await _seguro.leer(claveToken);
    if (token == null) {
      throw DispositivoNoAutorizado('Este teléfono no está activado como kiosco');
    }
    return token;
  }

  // ------------------------------------------------------------ cola
  Future<List<MarcajePendiente>> cola() async {
    final raw = await _almacen.leer(claveCola);
    if (raw == null) return [];
    return (json.decode(raw) as List)
        .map((m) => MarcajePendiente.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> _guardarCola(List<MarcajePendiente> cola) =>
      _almacen.escribir(claveCola, json.encode(cola.map((m) => m.toJson()).toList()));

  Future<int> cantidadPendientes() async => (await cola()).where((m) => !m.rechazado).length;

  Future<List<MarcajePendiente>> rechazados() async =>
      (await cola()).where((m) => m.rechazado).toList();

  Future<void> encolar(MarcajePendiente marcaje) => _exclusivo(() async {
        final actual = await cola();
        actual.add(marcaje);
        await _guardarCola(actual);
        final ultimos = await _ultimosLocales();
        ultimos[marcaje.trabajadorId] = {
          'id': marcaje.id,
          'tipo': marcaje.tipo,
          'en': marcaje.capturadoEn.toUtc().toIso8601String(),
        };
        await _almacen.escribir(claveUltimos, json.encode(ultimos));
      });

  /// Quita un marcaje rechazado de la lista (el supervisor ya lo revisó).
  Future<void> descartar(String id) => _exclusivo(() async {
        final actual = await cola();
        for (final m in actual.where((m) => m.id == id && m.rechazado)) {
          if (m.fotoRef != null) await _fotos.borrar(m.fotoRef!);
        }
        actual.removeWhere((m) => m.id == id && m.rechazado);
        await _guardarCola(actual);
      });

  // ------------------------------------------------------------ entrada / salida
  Future<Map<String, dynamic>> _ultimosLocales() async {
    final raw = await _almacen.leer(claveUltimos);
    return raw == null ? {} : Map<String, dynamic>.from(json.decode(raw));
  }

  /// Último marcaje conocido de cada trabajador: el más reciente entre lo que dijo el
  /// servidor y lo marcado en este teléfono.
  Future<Map<String, ({String tipo, DateTime en})>> ultimosMarcajes(KioscoConfig config) async {
    final res = <String, ({String tipo, DateTime en})>{};
    for (final t in config.trabajadores) {
      if (t.ultimoTipo != null && t.ultimoMarcaje != null) {
        res[t.id] = (tipo: t.ultimoTipo!, en: t.ultimoMarcaje!);
      }
    }
    final locales = await _ultimosLocales();
    locales.forEach((trabajadorId, valor) {
      final en = DateTime.parse(valor['en']);
      final previo = res[trabajadorId];
      if (previo == null || en.isAfter(previo.en)) {
        res[trabajadorId] = (tipo: valor['tipo'], en: en);
      }
    });
    return res;
  }

  Future<String> tipoSiguientePara(KioscoConfig config, String trabajadorId) async {
    final ultimo = (await ultimosMarcajes(config))[trabajadorId];
    return tipoSiguiente(ultimoTipo: ultimo?.tipo, ultimoEn: ultimo?.en, ahora: _reloj().toUtc());
  }

  // ------------------------------------------------------------ sincronización
  Future<ResultadoSync>? _enCurso;

  /// Envía los marcajes pendientes. No lanza por falta de conexión (devuelve
  /// sinConexion = true); sí lanza DispositivoNoAutorizado.
  Future<ResultadoSync> sincronizar() {
    return _enCurso ??= _sincronizar().whenComplete(() => _enCurso = null);
  }

  Future<ResultadoSync> _sincronizar() async {
    final token = await _token();
    var aceptados = 0;
    final rechazadosAhora = <MarcajePendiente>[];
    var sinConexion = false;

    while (true) {
      final lote = (await cola()).where((m) => !m.rechazado).take(tamanoLote).toList();
      if (lote.isEmpty) break;

      final items = <Map<String, dynamic>>[];
      for (final m in lote) {
        final item = m.toApi();
        if (m.fotoRef != null) {
          final foto = await _fotos.leer(m.fotoRef!);
          if (foto != null) item['foto_jpeg_b64'] = base64Encode(foto);
        }
        items.add(item);
      }

      final http.Response r;
      try {
        r = await _enviar(() => _http.post(
              Uri.parse('${_apiUrl()}/marcajes/lote'),
              headers: {'Content-Type': 'application/json', 'X-Device-Token': token},
              body: json.encode({
                'enviado_en': _reloj().toUtc().toIso8601String(),
                'marcajes': items,
              }),
            ));
      } on SinConexion {
        sinConexion = true;
        break;
      }

      final resultados = (json.decode(utf8.decode(r.bodyBytes))['resultados'] as List)
          .cast<Map<String, dynamic>>();
      final porId = {for (final res in resultados) res['id']: res};

      final procesados = await _exclusivo(() async {
        final actual = await cola();
        final ultimos = await _ultimosLocales();
        var n = 0;
        final nueva = <MarcajePendiente>[];
        for (final m in actual) {
          final res = porId[m.id];
          if (res == null || m.rechazado) {
            nueva.add(m);
          } else if (res['estado'] == 'creado' || res['estado'] == 'duplicado') {
            aceptados++;
            n++;
            if (m.fotoRef != null) await _fotos.borrar(m.fotoRef!);
          } else {
            final rechazado = m.rechazar(res['error'] ?? 'Rechazado por el servidor');
            rechazadosAhora.add(rechazado);
            nueva.add(rechazado);
            n++;
            // Si era el último marcaje local de ese trabajador, ya no cuenta
            if (ultimos[m.trabajadorId]?['id'] == m.id) ultimos.remove(m.trabajadorId);
          }
        }
        await _guardarCola(nueva);
        await _almacen.escribir(claveUltimos, json.encode(ultimos));
        return n;
      });
      if (procesados == 0) break; // respuesta sin resultados para el lote: evitar bucle
    }

    if (!sinConexion) {
      final config = await configGuardada();
      final vieja = config == null ||
          _reloj().toUtc().difference(config.descargadaEn) > refrescoConfig ||
          aceptados > 0;
      if (vieja) {
        try {
          await actualizarConfig();
        } on SinConexion {
          sinConexion = true;
        }
      }
    }

    return ResultadoSync(
      aceptados: aceptados,
      rechazados: rechazadosAhora,
      pendientes: await cantidadPendientes(),
      sinConexion: sinConexion,
    );
  }

  /// Ejecuta la petición y traduce errores de red y de autenticación.
  Future<http.Response> _enviar(Future<http.Response> Function() peticion) async {
    final http.Response r;
    try {
      r = await peticion().timeout(timeout);
    } on TimeoutException {
      throw SinConexion('El servidor no respondió a tiempo');
    } on http.ClientException {
      throw SinConexion();
    } catch (e) {
      // SocketException / HandshakeException (dart:io) u otros errores de red
      throw SinConexion('Sin conexión con el servidor');
    }
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw DispositivoNoAutorizado(_mensajeError(r) ?? 'Dispositivo no autorizado');
    }
    if (r.statusCode >= 500) {
      throw SinConexion('El servidor tuvo un error (${r.statusCode}); se reintentará');
    }
    if (r.statusCode >= 400) {
      throw Exception(_mensajeError(r) ?? 'Error ${r.statusCode}');
    }
    return r;
  }

  String? _mensajeError(http.Response r) {
    try {
      final body = json.decode(utf8.decode(r.bodyBytes));
      if (body is Map && body['error'] != null) return body['error'].toString();
    } catch (_) {}
    return null;
  }
}
