import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:laborlog_app/models/kiosco.dart';
import 'package:laborlog_app/services/almacen.dart';
import 'package:laborlog_app/services/sync_service.dart';
import 'package:laborlog_app/utils/geo.dart';
import 'package:laborlog_app/utils/reglas_marcaje.dart';

const _url = 'http://servidor';
const _token = 'token-de-prueba';

Map<String, dynamic> _configJson({String? ultimoTipo, DateTime? ultimoEn}) => {
      'dispositivo_id': 'd1',
      'dispositivo_nombre': 'Kiosco BARI',
      'empresa_nombre': 'Constructora',
      'zona_horaria': 'America/Guatemala',
      'hora_servidor': DateTime.now().toUtc().toIso8601String(),
      'obra': {'id': 1, 'nombre': 'BARI', 'lat': '14.538364', 'lng': '-90.478339', 'radio_metros': 50},
      'trabajadores': [
        {
          'id': 't1',
          'nombre': 'Juan Perez',
          'codigo_empresa': 'A1',
          'ultimo_tipo': ultimoTipo,
          'ultimo_marcaje': ultimoEn?.toUtc().toIso8601String(),
        },
      ],
    };

MarcajePendiente _marcaje(String id, {String tipo = 'entrada', DateTime? en}) => MarcajePendiente(
      id: id,
      trabajadorId: 't1',
      trabajadorNombre: 'Juan Perez',
      obraId: 1,
      tipo: tipo,
      capturadoEn: (en ?? DateTime.now()).toUtc(),
      lat: 14.538364,
      lng: -90.478339,
      precisionMetros: 8,
    );

/// Servidor falso: responde /kiosco/config y /marcajes/lote.
class _ServidorFalso {
  final lotes = <Map<String, dynamic>>[];
  bool caido = false;
  int codigoLote = 200;
  Set<String> rechazar = {};
  Set<String> yaRecibidos = {};
  Map<String, dynamic> config = _configJson();

  MockClient get cliente => MockClient((req) async {
        if (caido) throw http.ClientException('sin red');
        if (req.headers['X-Device-Token'] != _token) {
          return http.Response(json.encode({'error': 'Token de dispositivo inválido'}), 401);
        }
        if (req.url.path == '/kiosco/config') {
          return http.Response.bytes(utf8.encode(json.encode(config)), 200);
        }
        if (req.url.path == '/marcajes/lote') {
          if (codigoLote != 200) return http.Response('{"error":"falla"}', codigoLote);
          final body = json.decode(req.body) as Map<String, dynamic>;
          lotes.add(body);
          final resultados = (body['marcajes'] as List).map((m) {
            final id = m['id'];
            if (rechazar.contains(id)) {
              return {'id': id, 'estado': 'rechazado', 'codigo': 422, 'error': 'Fuera del área de la obra'};
            }
            final estado = yaRecibidos.contains(id) ? 'duplicado' : 'creado';
            yaRecibidos.add(id);
            return {'id': id, 'estado': estado, 'codigo': 200};
          }).toList();
          return http.Response.bytes(
              utf8.encode(json.encode({'hora_servidor': '2026-01-01T00:00:00Z', 'resultados': resultados})),
              200);
        }
        return http.Response('', 404);
      });
}

void main() {
  late AlmacenMemoria almacen;
  late AlmacenMemoria seguro;
  late _ServidorFalso servidor;

  KioscoService crear() => KioscoService(
        almacen: almacen,
        almacenSeguro: seguro,
        client: servidor.cliente,
        apiUrl: () => _url,
      );

  setUp(() {
    almacen = AlmacenMemoria();
    seguro = AlmacenMemoria();
    servidor = _ServidorFalso();
  });

  group('activación', () {
    test('token válido guarda token y configuración', () async {
      final svc = crear();
      final config = await svc.activar('  $_token ');
      expect(config.obra!.nombre, 'BARI');
      expect(config.obra!.tieneGeocerca, isTrue);
      expect(await svc.estaActivado(), isTrue);
      expect((await svc.configGuardada())!.trabajadores.single.nombre, 'Juan Perez');
    });

    test('token inválido no se guarda', () async {
      final svc = crear();
      await expectLater(svc.activar('malo'), throwsA(isA<DispositivoNoAutorizado>()));
      expect(await svc.estaActivado(), isFalse);
    });

    test('sin conexión al activar', () async {
      servidor.caido = true;
      await expectLater(crear().activar(_token), throwsA(isA<SinConexion>()));
    });
  });

  group('cola offline', () {
    test('marcajes sin conexión quedan en cola y se envían al volver la señal', () async {
      final svc = crear();
      await svc.activar(_token);
      servidor.caido = true;
      await svc.encolar(_marcaje('m1'));
      await svc.encolar(_marcaje('m2', tipo: 'salida'));

      final sinRed = await svc.sincronizar();
      expect(sinRed.sinConexion, isTrue);
      expect(sinRed.pendientes, 2);

      servidor.caido = false;
      final r = await svc.sincronizar();
      expect(r.sinConexion, isFalse);
      expect(r.aceptados, 2);
      expect(r.pendientes, 0);
      expect(await svc.cola(), isEmpty);

      final enviado = servidor.lotes.single;
      expect(enviado['enviado_en'], endsWith('Z'));
      final m1 = (enviado['marcajes'] as List).first;
      expect(m1['id'], 'm1');
      expect(m1['timestamp_local'], endsWith('Z'));
      expect(m1['lat'], '14.538364');
      expect(m1['ubicacion_simulada'], isFalse);
    });

    test('duplicado (reenvío tras perder la respuesta) se quita de la cola', () async {
      final svc = crear();
      await svc.activar(_token);
      servidor.yaRecibidos.add('m1');
      await svc.encolar(_marcaje('m1'));
      final r = await svc.sincronizar();
      expect(r.aceptados, 1);
      expect(await svc.cola(), isEmpty);
    });

    test('rechazados quedan para revisión y no se reenvían', () async {
      final svc = crear();
      await svc.activar(_token);
      servidor.rechazar.add('m1');
      await svc.encolar(_marcaje('m1'));
      await svc.encolar(_marcaje('m2', en: DateTime.now().add(const Duration(minutes: 1))));

      final r = await svc.sincronizar();
      expect(r.aceptados, 1);
      expect(r.rechazados.single.id, 'm1');
      expect(r.rechazados.single.error, contains('Fuera del área'));
      expect(await svc.cantidadPendientes(), 0);

      // La siguiente sincronización no vuelve a enviar el rechazado
      await svc.sincronizar();
      expect(servidor.lotes.length, 1);

      await svc.descartar('m1');
      expect(await svc.rechazados(), isEmpty);
    });

    test('error 500 del servidor conserva la cola', () async {
      final svc = crear();
      await svc.activar(_token);
      servidor.codigoLote = 500;
      await svc.encolar(_marcaje('m1'));
      final r = await svc.sincronizar();
      expect(r.sinConexion, isTrue);
      expect(await svc.cantidadPendientes(), 1);
    });

    test('token revocado lanza DispositivoNoAutorizado y conserva la cola', () async {
      final svc = crear();
      await svc.activar(_token);
      await svc.encolar(_marcaje('m1'));
      await seguro.escribir(KioscoService.claveToken, 'revocado');
      await expectLater(svc.sincronizar(), throwsA(isA<DispositivoNoAutorizado>()));
      expect(await svc.cantidadPendientes(), 1);
    });

    test('lotes de máximo 100 marcajes', () async {
      final svc = crear();
      await svc.activar(_token);
      for (var i = 0; i < 230; i++) {
        await svc.encolar(_marcaje('m$i'));
      }
      final r = await svc.sincronizar();
      expect(r.aceptados, 230);
      expect(servidor.lotes.map((l) => (l['marcajes'] as List).length), [100, 100, 30]);
    });

    test('encolar durante una sincronización no pierde el marcaje', () async {
      final svc = crear();
      await svc.activar(_token);
      await svc.encolar(_marcaje('m1'));
      final sync = svc.sincronizar();
      await svc.encolar(_marcaje('m2'));
      await sync;
      final ids = (await svc.cola()).map((m) => m.id).toList();
      final enviados = servidor.lotes.expand((l) => l['marcajes'] as List).map((m) => m['id']);
      // m2 se envió en la misma sincronización o sigue pendiente, pero nunca se pierde
      expect(ids.contains('m2') || enviados.contains('m2'), isTrue);
    });

    test('desactivar borra token, configuración y cola', () async {
      final svc = crear();
      await svc.activar(_token);
      await svc.encolar(_marcaje('m1'));
      await svc.desactivar();
      expect(await svc.estaActivado(), isFalse);
      expect(await svc.configGuardada(), isNull);
      expect(await svc.cola(), isEmpty);
    });
  });

  group('entrada / salida', () {
    test('usa el último marcaje del servidor', () async {
      servidor.config = _configJson(
          ultimoTipo: 'entrada', ultimoEn: DateTime.now().subtract(const Duration(hours: 3)));
      final svc = crear();
      final config = await svc.activar(_token);
      expect(await svc.tipoSiguientePara(config, 't1'), 'salida');
    });

    test('un marcaje local más reciente manda sobre el del servidor', () async {
      servidor.config = _configJson(
          ultimoTipo: 'entrada', ultimoEn: DateTime.now().subtract(const Duration(hours: 3)));
      final svc = crear();
      final config = await svc.activar(_token);
      servidor.caido = true;
      await svc.encolar(_marcaje('m1', tipo: 'salida'));
      expect(await svc.tipoSiguientePara(config, 't1'), 'entrada');
    });

    test('si el servidor rechaza el marcaje local, se vuelve a proponer lo mismo', () async {
      final svc = crear();
      final config = await svc.activar(_token);
      servidor.rechazar.add('m1');
      await svc.encolar(_marcaje('m1'));
      expect(await svc.tipoSiguientePara(config, 't1'), 'salida');
      await svc.sincronizar();
      expect(await svc.tipoSiguientePara(config, 't1'), 'entrada');
    });

    test('regla de 20 horas (turno nocturno y entrada olvidada)', () {
      final ahora = DateTime.utc(2026, 11, 14, 6);
      expect(tipoSiguiente(ahora: ahora), 'entrada');
      expect(
          tipoSiguiente(ultimoTipo: 'entrada', ultimoEn: ahora.subtract(const Duration(hours: 10)), ahora: ahora),
          'salida');
      expect(
          tipoSiguiente(ultimoTipo: 'entrada', ultimoEn: ahora.subtract(const Duration(hours: 21)), ahora: ahora),
          'entrada');
      expect(
          tipoSiguiente(ultimoTipo: 'salida', ultimoEn: ahora.subtract(const Duration(hours: 1)), ahora: ahora),
          'entrada');
    });
  });

  test('distancia Haversine coincide con el servidor', () {
    // ~0.01° de latitud son ~1112 m
    final d = distanciaMetros(14.538364, -90.478339, 14.548364, -90.478339);
    expect(d, closeTo(1112, 2));
    expect(distanciaMetros(14.5, -90.4, 14.5, -90.4), 0);
  });
}
