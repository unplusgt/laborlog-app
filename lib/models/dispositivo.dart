class Dispositivo {
  final String id;
  final String? nombre;
  final String? tokenFcm;
  final DateTime? lastSync;
  final String? licencia;

  Dispositivo({
    required this.id,
    this.nombre,
    this.tokenFcm,
    this.lastSync,
    this.licencia,
  });

  factory Dispositivo.fromJson(Map<String, dynamic> json) {
    return Dispositivo(
      id: json['id'],
      nombre: json['nombre'],
      tokenFcm: json['token_fcm'],
      lastSync: json['last_sync'] != null 
          ? DateTime.parse(json['last_sync'])
          : null,
      licencia: json['licencia'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'token_fcm': tokenFcm,
      'last_sync': lastSync?.toIso8601String(),
      'licencia': licencia,
    };
  }
}