// Zonas de entrega (HU-16, #60), con la forma que envía GET /zonas-entrega: la tienda las da de alta
// en su panel del sitio web y les pone un orden.
class ZonaEntrega {
  const ZonaEntrega({required this.id, required this.nombre, this.orden = 0});

  factory ZonaEntrega.fromJson(Map<String, dynamic> json) =>
      ZonaEntrega(id: json['id'] as int? ?? 0, nombre: (json['nombre'] as String? ?? '').trim(), orden: json['orden'] as int? ?? 0);

  final int id;
  final String nombre;
  final int orden;
}

// Lo que el sitio web muestra en "Entregas a domicilio" de Nuestra ubicación: las zonas y los datos
// de la tienda para recoger o preguntar. Cada parte puede faltar si su consulta falló.
class InfoEntregas {
  const InfoEntregas({this.zonas, this.direccion, this.horario, this.whatsapp});

  // null: no se pudieron consultar. Lista vacía: la tienda no tiene zonas activas.
  final List<ZonaEntrega>? zonas;
  final String? direccion;
  final String? horario;
  // Solo dígitos, por ejemplo "527713321421".
  final String? whatsapp;

  // Mismo mensaje que el botón "Preguntar por mi zona" del sitio web.
  Uri? get preguntarPorMiZona => whatsapp == null ? null : Uri.https('wa.me', '/$whatsapp', {'text': 'Hola, ¿hacen entregas en mi zona?'});
}
