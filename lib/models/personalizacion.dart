// Solicitudes de personalización de una pieza (HU-13), con la forma que envía el backend.

// PostgreSQL envía los montos (numeric) como texto, por ejemplo "580.32".
double? _aNumero(Object? valor) => switch (valor) {
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};

// El backend guarda las fechas en UTC y a veces las envía sin zona; sin la Z se tomarían como hora local.
DateTime? _aFecha(Object? valor) {
  if (valor is! String) return null;
  final conZona = RegExp(r'(Z|[+-]\d{2}(:?\d{2})?)$').hasMatch(valor) ? valor : '${valor}Z';
  return DateTime.tryParse(conZona)?.toLocal();
}

enum EstadoSolicitud { pendiente, aprobada, rechazada }

// Lo que el cliente pidió y lo que respondió la tienda (GET /personalizacion/mis-solicitudes).
class SolicitudPersonalizacion {
  const SolicitudPersonalizacion({
    required this.id,
    required this.productoId,
    required this.productoNombre,
    required this.detalle,
    required this.estado,
    this.productoImagen,
    this.precioPersonalizacion,
    this.imagenReferencia,
    this.motivoRechazo,
    this.utilizada = false,
    this.fechaCreacion,
    this.fechaRespuesta,
  });

  factory SolicitudPersonalizacion.fromJson(Map<String, dynamic> json) => SolicitudPersonalizacion(
    id: json['id'] as int,
    productoId: json['producto_id'] as int,
    productoNombre: json['producto_nombre'] as String? ?? '',
    productoImagen: json['producto_imagen'] as String?,
    precioPersonalizacion: _aNumero(json['precio_personalizacion']),
    detalle: json['detalle'] as String? ?? '',
    imagenReferencia: json['imagen_referencia_url'] as String?,
    estado: switch (json['estado']) {
      'aprobada' => EstadoSolicitud.aprobada,
      'rechazada' => EstadoSolicitud.rechazada,
      _ => EstadoSolicitud.pendiente,
    },
    motivoRechazo: json['motivo_rechazo'] as String?,
    utilizada: json['utilizada'] as bool? ?? false,
    fechaCreacion: _aFecha(json['fecha_creacion']),
    fechaRespuesta: _aFecha(json['fecha_respuesta']),
  );

  final int id;
  final int productoId;
  final String productoNombre;
  final String? productoImagen;
  // Costo extra de personalizar la pieza; 0 o null si no tiene.
  final double? precioPersonalizacion;
  final String detalle;
  final String? imagenReferencia;
  final EstadoSolicitud estado;
  final String? motivoRechazo;
  // Ya se agregó al carrito con la personalización aprobada.
  final bool utilizada;
  final DateTime? fechaCreacion;
  final DateTime? fechaRespuesta;

  // Aprobada y sin usar: el cliente ya puede comprar la pieza personalizada.
  bool get lista => estado == EstadoSolicitud.aprobada && !utilizada;
}

// Respuesta al enviar una solicitud: la solicitud creada y los días que tarda la tienda en revisarla.
class SolicitudEnviada {
  const SolicitudEnviada({required this.solicitud, required this.diasEstimados});

  final SolicitudPersonalizacion solicitud;
  final int diasEstimados;
}
