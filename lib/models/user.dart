class UsuarioAdmin {
  final String id;
  final String nombre;
  final String email;
  final String? rol;

  UsuarioAdmin({
    required this.id,
    required this.nombre,
    required this.email,
    this.rol,
  });

  factory UsuarioAdmin.fromJson(Map<String, dynamic> json) {
    return UsuarioAdmin(
      id: json['id'],
      nombre: json['nombre'],
      email: json['email'],
      rol: json['rol'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'rol': rol,
    };
  }
}

// Alias para compatibilidad con código existente
typedef User = UsuarioAdmin;
