class Trabajador {
  final String id;
  final String nombre;
  final String? dni;
  final String? telefono;
  final String? codigoEmpresa;
  final DateTime? fechaRegistro;
  final String? fotoRegistroPath;
  final bool activo;

  Trabajador({
    required this.id,
    required this.nombre,
    this.dni,
    this.telefono,
    this.codigoEmpresa,
    this.fechaRegistro,
    this.fotoRegistroPath,
    this.activo = true,
  });

  factory Trabajador.fromJson(Map<String, dynamic> json) {
    return Trabajador(
      id: json['id'],
      nombre: json['nombre'],
      dni: json['dni'],
      telefono: json['telefono'],
      codigoEmpresa: json['codigo_empresa'],
      fechaRegistro: json['fecha_registro'] != null 
          ? DateTime.parse(json['fecha_registro']) 
          : null,
      fotoRegistroPath: json['foto_registro_path'],
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'dni': dni,
      'telefono': telefono,
      'codigo_empresa': codigoEmpresa,
      'fecha_registro': fechaRegistro?.toIso8601String(),
      'foto_registro_path': fotoRegistroPath,
      'activo': activo,
    };
  }
}