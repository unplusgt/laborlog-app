/// Usuario que inicia sesión (plataforma, superadmin, jefe o supervisor).
class UsuarioAdmin {
  final String id;
  final String nombre;
  final String usuario;
  final String? email;
  final String? rol;
  final bool activo;

  /// Supervisor: obras asignadas.
  final List<int> obras;

  /// Solo en la sesión actual (/me)
  final String? empresaCodigo;
  final String? empresaNombre;

  UsuarioAdmin({
    required this.id,
    required this.nombre,
    required this.usuario,
    this.email,
    this.rol,
    this.activo = true,
    this.obras = const [],
    this.empresaCodigo,
    this.empresaNombre,
  });

  factory UsuarioAdmin.fromJson(Map<String, dynamic> json) {
    return UsuarioAdmin(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      usuario: json['usuario'] ?? '',
      email: json['email'],
      rol: json['rol'],
      activo: json['activo'] ?? true,
      obras: ((json['obras'] as List?) ?? []).map((e) => e as int).toList(),
      empresaCodigo: json['empresa_codigo'],
      empresaNombre: json['empresa_nombre'],
    );
  }
}

// Alias para compatibilidad con código existente
typedef User = UsuarioAdmin;

/// Roles del sistema (deben coincidir con laborlog_backend/auth.py).
class Roles {
  static const plataforma = 'plataforma';
  static const superadmin = 'superadmin';
  static const jefe = 'jefe';
  static const supervisor = 'supervisor';

  static String nombre(String? rol) => switch (rol) {
        plataforma => 'Plataforma',
        superadmin => 'Super admin',
        jefe => 'Jefe',
        supervisor => 'Supervisor',
        _ => rol ?? '',
      };
}
