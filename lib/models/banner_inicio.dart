// Banner del carrusel del Inicio (#244): los mismos que la tienda administra en el panel del sitio
// web (página "inicio", sección del carrusel).
class BannerInicio {
  const BannerInicio({required this.titulo, this.descripcion, this.imagen, this.enlace});

  factory BannerInicio.fromJson(Map<String, dynamic> json) => BannerInicio(
    titulo: (json['titulo'] as String? ?? '').trim(),
    descripcion: _texto(json['descripcion']),
    imagen: _texto(json['imagen_url']),
    enlace: _texto(json['enlace_url']),
  );

  final String titulo;
  final String? descripcion;
  final String? imagen;
  final String? enlace;

  // En el sitio web el banner de la ubicación lleva a la página de ubicación; en la app, a Zonas de
  // entrega, que muestra la dirección de la tienda. Los demás llevan al catálogo.
  bool get llevaAUbicacion => enlace?.contains('ubicacion') ?? false;

  static String? _texto(Object? valor) {
    final t = (valor as String?)?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}
