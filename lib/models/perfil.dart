// Datos de la cuenta del cliente para Mi perfil (HU-14), con la forma que envía
// GET /auth/profile (la misma ruta que usa el perfil del sitio web).
class Perfil {
  const Perfil({required this.nombre, required this.email, this.telefono, this.fotoUrl, this.fechaRegistro});

  factory Perfil.fromJson(Map<String, dynamic> json) => Perfil(
    nombre: (json['nombre'] as String? ?? '').trim(),
    email: json['email'] as String? ?? '',
    telefono: json['telefono'] as String?,
    fotoUrl: (json['foto_perfil_url'] as String?)?.trim().isEmpty ?? true ? null : json['foto_perfil_url'] as String,
    fechaRegistro: _aFecha(json['fecha_creacion']),
  );

  final String nombre;
  final String email;
  final String? telefono;
  final String? fotoUrl;
  final DateTime? fechaRegistro;

  // "Ana Martínez" → "AM", como el avatar del boceto; con un solo nombre, su primera letra.
  String get iniciales {
    final partes = nombre.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return email.isEmpty ? '?' : email[0].toUpperCase();
    return partes.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

// El backend guarda las fechas en UTC y a veces las envía sin zona.
DateTime? _aFecha(Object? valor) {
  if (valor is! String) return null;
  final conZona = RegExp(r'(Z|[+-]\d{2}(:?\d{2})?)$').hasMatch(valor) ? valor : '${valor}Z';
  return DateTime.tryParse(conZona)?.toLocal();
}

// Lo que el cliente lleva en la tienda: los números del boceto (Pedidos · Apartados · Favoritos).
// Si una cuenta no se pudo traer, queda en null y la pantalla muestra "–".
class ResumenCliente {
  const ResumenCliente({this.pedidos, this.apartados, this.favoritos});

  final int? pedidos;
  final int? apartados;
  final int? favoritos;
}
