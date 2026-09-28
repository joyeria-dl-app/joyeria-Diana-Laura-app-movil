class Usuario {
  const Usuario({required this.email, required this.nombre, required this.rol});

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        email: json['email'] as String? ?? '',
        nombre: json['nombre'] as String? ?? '',
        rol: json['rol'] as String? ?? 'cliente',
      );

  final String email;
  final String nombre;
  final String rol;

  Map<String, dynamic> toJson() => {'email': email, 'nombre': nombre, 'rol': rol};
}
