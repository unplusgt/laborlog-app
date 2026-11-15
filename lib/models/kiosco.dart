/// Configuración que el teléfono descarga de GET /kiosco/config y guarda para
/// poder marcar sin conexión.
class KioscoConfig {
  final String dispositivoId;
  final String? dispositivoNombre;
  final String empresaNombre;
  final String? empresaCodigo;
  final String zonaHoraria;
  final KioscoObra? obra;
  final List<KioscoTrabajador> trabajadores;
  final DateTime descargadaEn;

  KioscoConfig({
    required this.dispositivoId,
    this.dispositivoNombre,
    required this.empresaNombre,
    this.empresaCodigo,
    required this.zonaHoraria,
    this.obra,
    required this.trabajadores,
    required this.descargadaEn,
  });

  factory KioscoConfig.fromJson(Map<String, dynamic> json) {
    return KioscoConfig(
      dispositivoId: json['dispositivo_id'],
      dispositivoNombre: json['dispositivo_nombre'],
      empresaNombre: json['empresa_nombre'] ?? '',
      empresaCodigo: json['empresa_codigo'],
      zonaHoraria: json['zona_horaria'] ?? '',
      obra: json['obra'] != null ? KioscoObra.fromJson(json['obra']) : null,
      trabajadores: ((json['trabajadores'] as List?) ?? [])
          .map((t) => KioscoTrabajador.fromJson(t))
          .toList(),
      descargadaEn: json['descargada_en'] != null
          ? DateTime.parse(json['descargada_en'])
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'dispositivo_id': dispositivoId,
        'dispositivo_nombre': dispositivoNombre,
        'empresa_nombre': empresaNombre,
        'empresa_codigo': empresaCodigo,
        'zona_horaria': zonaHoraria,
        'obra': obra?.toJson(),
        'trabajadores': trabajadores.map((t) => t.toJson()).toList(),
        'descargada_en': descargadaEn.toUtc().toIso8601String(),
      };
}

class KioscoObra {
  final int id;
  final String nombre;
  final double? lat;
  final double? lng;
  final int? radioMetros;

  KioscoObra({required this.id, required this.nombre, this.lat, this.lng, this.radioMetros});

  bool get tieneGeocerca => lat != null && lng != null && (radioMetros ?? 0) > 0;

  factory KioscoObra.fromJson(Map<String, dynamic> json) => KioscoObra(
        id: json['id'],
        nombre: json['nombre'] ?? '',
        lat: double.tryParse('${json['lat'] ?? ''}'.trim()),
        lng: double.tryParse('${json['lng'] ?? ''}'.trim()),
        radioMetros: json['radio_metros'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'lat': lat?.toString(),
        'lng': lng?.toString(),
        'radio_metros': radioMetros,
      };
}

class KioscoTrabajador {
  final String id;
  final String nombre;
  final String? codigoEmpresa;

  /// Último marcaje conocido por el servidor (dentro de la ventana de turno).
  final String? ultimoTipo;
  final DateTime? ultimoMarcaje;

  /// Huella facial (base64) para reconocerlo sin conexión; null si no tiene rostro registrado.
  final String? huellaB64;

  KioscoTrabajador({
    required this.id,
    required this.nombre,
    this.codigoEmpresa,
    this.ultimoTipo,
    this.ultimoMarcaje,
    this.huellaB64,
  });

  bool get tieneRostro => huellaB64 != null;

  factory KioscoTrabajador.fromJson(Map<String, dynamic> json) => KioscoTrabajador(
        id: json['id'],
        nombre: json['nombre'] ?? '',
        codigoEmpresa: json['codigo_empresa'],
        ultimoTipo: json['ultimo_tipo'],
        ultimoMarcaje: json['ultimo_marcaje'] != null
            ? DateTime.parse(json['ultimo_marcaje'])
            : null,
        huellaB64: json['huella_b64'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'codigo_empresa': codigoEmpresa,
        'ultimo_tipo': ultimoTipo,
        'ultimo_marcaje': ultimoMarcaje?.toUtc().toIso8601String(),
        'huella_b64': huellaB64,
      };
}

/// Marcaje capturado en el teléfono, guardado hasta que el servidor lo acepte.
class MarcajePendiente {
  final String id;
  final String trabajadorId;
  final String trabajadorNombre;
  final int obraId;
  final String tipo;
  final DateTime capturadoEn; // UTC, según el reloj del teléfono
  final double lat;
  final double lng;
  final double? precisionMetros;
  final bool ubicacionSimulada;

  /// rostro (reconocido por la cámara) | manual (eligió su nombre)
  final String metodo;
  final double? similitud;
  final String? pruebaVida;

  /// Referencia a la foto guardada en el teléfono (ver AlmacenFotos)
  final String? fotoRef;

  /// pendiente | rechazado
  final String estado;
  final String? error;

  MarcajePendiente({
    required this.id,
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.obraId,
    required this.tipo,
    required this.capturadoEn,
    required this.lat,
    required this.lng,
    this.precisionMetros,
    this.ubicacionSimulada = false,
    this.metodo = 'manual',
    this.similitud,
    this.pruebaVida,
    this.fotoRef,
    this.estado = 'pendiente',
    this.error,
  });

  bool get rechazado => estado == 'rechazado';

  MarcajePendiente rechazar(String motivo) => MarcajePendiente(
        id: id,
        trabajadorId: trabajadorId,
        trabajadorNombre: trabajadorNombre,
        obraId: obraId,
        tipo: tipo,
        capturadoEn: capturadoEn,
        lat: lat,
        lng: lng,
        precisionMetros: precisionMetros,
        ubicacionSimulada: ubicacionSimulada,
        metodo: metodo,
        similitud: similitud,
        pruebaVida: pruebaVida,
        fotoRef: fotoRef,
        estado: 'rechazado',
        error: motivo,
      );

  /// Formato que espera POST /marcajes/lote (la foto se agrega al enviar).
  Map<String, dynamic> toApi() => {
        'id': id,
        'trabajador_id': trabajadorId,
        'obra_id': obraId,
        'tipo': tipo,
        'timestamp_local': capturadoEn.toUtc().toIso8601String(),
        'lat': lat.toStringAsFixed(6),
        'lng': lng.toStringAsFixed(6),
        if (precisionMetros != null) 'precision_metros': precisionMetros,
        'ubicacion_simulada': ubicacionSimulada,
        'metodo': metodo,
        if (similitud != null) 'similitud': double.parse(similitud!.toStringAsFixed(4)),
        if (pruebaVida != null) 'prueba_vida': pruebaVida,
      };

  Map<String, dynamic> toJson() => {
        ...toApi(),
        'trabajador_nombre': trabajadorNombre,
        'foto_ref': fotoRef,
        'estado': estado,
        'error': error,
      };

  factory MarcajePendiente.fromJson(Map<String, dynamic> json) => MarcajePendiente(
        id: json['id'],
        trabajadorId: json['trabajador_id'],
        trabajadorNombre: json['trabajador_nombre'] ?? '',
        obraId: json['obra_id'],
        tipo: json['tipo'],
        capturadoEn: DateTime.parse(json['timestamp_local']),
        lat: double.parse(json['lat']),
        lng: double.parse(json['lng']),
        precisionMetros: (json['precision_metros'] as num?)?.toDouble(),
        ubicacionSimulada: json['ubicacion_simulada'] ?? false,
        metodo: json['metodo'] ?? 'manual',
        similitud: (json['similitud'] as num?)?.toDouble(),
        pruebaVida: json['prueba_vida'],
        fotoRef: json['foto_ref'],
        estado: json['estado'] ?? 'pendiente',
        error: json['error'],
      );
}
