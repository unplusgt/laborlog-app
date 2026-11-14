class Dispositivo {
  final String id;
  final String? nombre;
  final String? tokenFcm;
  final DateTime? lastSync;
  final String? licencia;

  /// Obra donde está instalado (modo kiosco).
  final int? obraId;
  final bool activo;

  /// Solo viene al crear el dispositivo o al generar un token nuevo.
  final String? token;

  Dispositivo({
    required this.id,
    this.nombre,
    this.tokenFcm,
    this.lastSync,
    this.licencia,
    this.obraId,
    this.activo = true,
    this.token,
  });

  factory Dispositivo.fromJson(Map<String, dynamic> json) {
    return Dispositivo(
      id: json['id'],
      nombre: json['nombre'],
      tokenFcm: json['token_fcm'],
      lastSync: _parseUtc(json['last_sync']),
      licencia: json['licencia'],
      obraId: json['obra_id'],
      activo: json['activo'] ?? true,
      token: json['token'],
    );
  }

  /// El servidor guarda last_sync en UTC sin zona horaria.
  static DateTime? _parseUtc(String? s) {
    if (s == null) return null;
    final conZona = s.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(s);
    return DateTime.parse(conZona ? s : '${s}Z');
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'token_fcm': tokenFcm,
      'licencia': licencia,
      'obra_id': obraId,
    };
  }
}
