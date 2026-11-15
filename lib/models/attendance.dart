class Marcaje {
  final String id;
  final String trabajadorId;
  final int obraId;
  final String tipo; // 'entrada' o 'salida'
  final DateTime? timestampServer;
  final DateTime timestampLocal;
  final String origen; // ID del dispositivo
  final String? lat;
  final String? lng;
  final String? fotoPath;
  final String? estadoSync;
  final String? razonConflicto;
  final double? precisionMetros;
  final bool ubicacionSimulada;
  final bool capturadoOffline;

  Marcaje({
    required this.id,
    required this.trabajadorId,
    required this.obraId,
    required this.tipo,
    this.timestampServer,
    required this.timestampLocal,
    required this.origen,
    this.lat,
    this.lng,
    this.fotoPath,
    this.estadoSync,
    this.razonConflicto,
    this.precisionMetros,
    this.ubicacionSimulada = false,
    this.capturadoOffline = false,
  });

  factory Marcaje.fromJson(Map<String, dynamic> json) {
    return Marcaje(
      id: json['id'],
      trabajadorId: json['trabajador_id'],
      obraId: json['obra_id'],
      tipo: json['tipo'],
      timestampServer: json['timestamp_server'] != null 
          ? DateTime.parse(json['timestamp_server'])
          : null,
      timestampLocal: DateTime.parse(json['timestamp_local']),
      origen: json['origen'] ?? '',
      lat: json['lat'],
      lng: json['lng'],
      fotoPath: json['foto_path'],
      estadoSync: json['estado_sync'],
      razonConflicto: json['razon_conflicto'],
      precisionMetros: (json['precision_metros'] as num?)?.toDouble(),
      capturadoOffline: json['capturado_offline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Id generado en el cliente: si se reenvía, el servidor no lo duplica
      if (id.isNotEmpty) 'id': id,
      'trabajador_id': trabajadorId,
      'obra_id': obraId,
      'tipo': tipo,
      'timestamp_local': timestampLocal.toIso8601String(),
      if (origen.isNotEmpty) 'origen': origen,
      'lat': lat,
      'lng': lng,
      'foto_path': fotoPath,
      if (precisionMetros != null) 'precision_metros': precisionMetros,
      'ubicacion_simulada': ubicacionSimulada,
    };
  }

  // Helper para obtener coordenadas como double
  double? get latitude => lat != null ? double.tryParse(lat!) : null;
  double? get longitude => lng != null ? double.tryParse(lng!) : null;

  @override
  String toString() {
    return 'Marcaje(id: $id, trabajadorId: $trabajadorId, obraId: $obraId, tipo: $tipo, '
           'timestamp: ${timestampLocal.toString().substring(0, 19)}, origen: $origen, '
           'lat: ${lat ?? "N/A"}, lng: ${lng ?? "N/A"})';
  }
}

// Alias para compatibilidad con código existente
typedef Attendance = Marcaje;
