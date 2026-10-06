// Modelos de pedidos y apartados (HU-11), con la forma que envía el backend.

// PostgreSQL envía los montos (numeric) como texto, por ejemplo "580.32".
double? _aNumero(Object? valor) => switch (valor) {
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};

DateTime? _aFecha(Object? valor) => valor is String ? DateTime.tryParse(valor)?.toLocal() : null;

// Método de pago dado de alta en el sitio (GET /carrito/metodos-pago).
class MetodoPago {
  const MetodoPago({required this.id, required this.nombre, required this.codigo, this.enLinea = false});

  factory MetodoPago.fromJson(Map<String, dynamic> json) => MetodoPago(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    codigo: json['codigo'] as String? ?? '',
    enLinea: json['es_pasarela'] as bool? ?? false,
  );

  final int id;
  final String nombre;
  // efectivo, transferencia, mercadopago o paypal.
  final String codigo;
  // Mercado Pago y PayPal: se paga en línea cuando el trabajador confirma el pedido.
  final bool enLinea;

  // El efectivo solo tiene sentido al recoger en tienda.
  bool get soloEnTienda => codigo == 'efectivo';
}

// Métodos de pago y costo del envío a domicilio, como los usa el sitio web.
class OpcionesCompra {
  const OpcionesCompra({required this.metodos, required this.costoEnvio});

  factory OpcionesCompra.fromJson(Map<String, dynamic> json) => OpcionesCompra(
    metodos: (json['metodos'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>().map(MetodoPago.fromJson).toList(),
    costoEnvio: _aNumero(json['costo_envio']) ?? 0,
  );

  final List<MetodoPago> metodos;
  final double costoEnvio;

  List<MetodoPago> metodosPara({required bool domicilio}) => domicilio ? metodos.where((m) => !m.soloEnTienda).toList() : metodos;
}

// Plan para liquidar un apartado (GET /apartados/planes).
class PlanAbono {
  const PlanAbono({required this.id, required this.nombre, required this.intervaloDias, required this.porcentaje, this.descripcion});

  factory PlanAbono.fromJson(Map<String, dynamic> json) => PlanAbono(
    id: json['id'] as int,
    nombre: json['nombre'] as String? ?? '',
    intervaloDias: json['intervalo_dias'] as int? ?? 0,
    porcentaje: _aNumero(json['porcentaje_abono']) ?? 0,
    descripcion: json['descripcion'] as String?,
  );

  final int id;
  final String nombre;
  final int intervaloDias;
  // Porcentaje del total que se paga en cada abono después del anticipo.
  final double porcentaje;
  final String? descripcion;

  // Pagos que quedan después del abono de hoy; cada uno es el porcentaje del plan sobre el total.
  List<double> pagos({required double total, required double abonoHoy}) {
    var saldo = double.parse((total - abonoHoy).toStringAsFixed(2));
    final cuota = double.parse((total * porcentaje / 100).toStringAsFixed(2));
    final pagos = <double>[];
    while (saldo > 0.009 && cuota > 0) {
      final monto = saldo < cuota ? saldo : cuota;
      pagos.add(monto);
      saldo = double.parse((saldo - monto).toStringAsFixed(2));
    }
    return pagos;
  }
}

// Dirección de entrega para un pedido a domicilio.
class DireccionEntrega {
  const DireccionEntrega({
    required this.calle,
    required this.numero,
    required this.colonia,
    required this.ciudad,
    required this.codigoPostal,
    this.estado = 'Hidalgo',
    this.numeroInterior,
    this.referencias,
    this.telefono,
  });

  final String calle;
  final String numero;
  final String? numeroInterior;
  final String colonia;
  final String ciudad;
  final String estado;
  final String codigoPostal;
  final String? referencias;
  final String? telefono;

  bool get completa => calle.trim().isNotEmpty && colonia.trim().isNotEmpty && codigoPostal.trim().isNotEmpty;

  // Mismo texto que arma el sitio web: "Morelos 12, Centro, Huejutla de Reyes, Hidalgo, CP 43000".
  String get texto => [
    numero.trim().isNotEmpty ? '${calle.trim()} ${numero.trim()}' : calle.trim(),
    colonia.trim(),
    ciudad.trim(),
    estado.trim(),
    if (codigoPostal.trim().isNotEmpty) 'CP ${codigoPostal.trim()}',
  ].where((p) => p.isNotEmpty).join(', ');

  Map<String, dynamic> toJson() => {
    'calle': calle.trim(),
    'numero': numero.trim(),
    'numero_interior': numeroInterior?.trim(),
    'colonia': colonia.trim(),
    'ciudad': ciudad.trim(),
    'estado_dir': estado.trim(),
    'codigo_postal': codigoPostal.trim(),
    'referencias': referencias?.trim(),
    'telefono_contacto': telefono?.trim(),
    'texto_completo': texto,
  };
}

// Una pieza dentro de un pedido.
class PiezaPedido {
  const PiezaPedido({required this.nombre, required this.cantidad, required this.precioUnitario, this.imagen, this.talla});

  factory PiezaPedido.fromJson(Map<String, dynamic> json) => PiezaPedido(
    nombre: json['producto_nombre'] as String? ?? json['nombre'] as String? ?? '',
    cantidad: json['cantidad'] as int? ?? 1,
    precioUnitario: _aNumero(json['precio_unitario']) ?? 0,
    imagen: json['producto_imagen'] as String? ?? json['imagen'] as String?,
    talla: json['talla_medida'] as String?,
  );

  final String nombre;
  final int cantidad;
  final double precioUnitario;
  final String? imagen;
  final String? talla;
}

// Un cambio de estado del pedido con su fecha.
class CambioEstado {
  const CambioEstado({required this.estado, required this.fecha, this.comentario});

  factory CambioEstado.fromJson(Map<String, dynamic> json) =>
      CambioEstado(estado: json['estado'] as String? ?? '', fecha: _aFecha(json['fecha']), comentario: json['comentario'] as String?);

  final String estado;
  final DateTime? fecha;
  final String? comentario;
}

// Pedido del cliente (GET /carrito/pedidos/mis).
class Pedido {
  const Pedido({
    required this.id,
    required this.folio,
    required this.estado,
    required this.total,
    this.costoEnvio = 0,
    this.domicilio = false,
    this.direccion,
    this.metodoPago,
    this.metodoPagoCodigo,
    this.estadoPago,
    this.fechaCreacion,
    this.fechaEstimada,
    this.numeroGuia,
    this.paqueteria,
    this.codigoEntrega,
    this.comprobanteUrl,
    this.piezas = const [],
    this.historial = const [],
  });

  factory Pedido.fromJson(Map<String, dynamic> json) => Pedido(
    id: json['id'] as int,
    folio: json['folio'] as String? ?? '#${json['id']}',
    estado: json['estado'] as String? ?? 'pendiente',
    total: _aNumero(json['total']) ?? 0,
    costoEnvio: _aNumero(json['costo_envio']) ?? 0,
    domicilio: json['tipo_entrega'] == 'domicilio',
    direccion: json['direccion_envio'] as String?,
    metodoPago: json['metodo_pago_nombre'] as String?,
    metodoPagoCodigo: json['metodo_pago_codigo'] as String?,
    estadoPago: json['estado_pago'] as String?,
    fechaCreacion: _aFecha(json['fecha_creacion']),
    fechaEstimada: _aFecha(json['fecha_estimada_entrega']),
    numeroGuia: json['numero_guia'] as String?,
    paqueteria: json['paqueteria'] as String?,
    codigoEntrega: json['codigo_entrega'] as String?,
    comprobanteUrl: json['comprobante_transferencia_url'] as String?,
    piezas: (json['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>().map(PiezaPedido.fromJson).toList(),
    historial: (json['historial'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>().map(CambioEstado.fromJson).toList(),
  );

  final int id;
  final String folio;
  // pendiente, confirmado, en_preparacion, enviado, entregado, cancelado o expirado.
  final String estado;
  final double total;
  final double costoEnvio;
  final bool domicilio;
  final String? direccion;
  final String? metodoPago;
  final String? metodoPagoCodigo;
  final String? estadoPago;
  final DateTime? fechaCreacion;
  final DateTime? fechaEstimada;
  final String? numeroGuia;
  final String? paqueteria;
  final String? codigoEntrega;
  // Comprobante que subió el cliente cuando paga por transferencia.
  final String? comprobanteUrl;
  final List<PiezaPedido> piezas;
  final List<CambioEstado> historial;

  int get totalPiezas => piezas.fold(0, (suma, p) => suma + p.cantidad);
  bool get enCurso => !terminado;
  bool get entregado => estado == 'entregado';
  bool get terminado => const {'entregado', 'cancelado', 'expirado'}.contains(estado);
  bool get cancelado => estado == 'cancelado' || estado == 'expirado';
  // Transferencia sin comprobante todavía: el cliente debe subirlo (9e).
  bool get esperaComprobante => estado == 'pendiente' && metodoPagoCodigo == 'transferencia' && comprobanteUrl == null;

  // Fecha en que el pedido llegó a un estado: "pendiente" es la creación; los demás salen del historial.
  DateTime? fechaDe(String estadoBuscado) {
    if (estadoBuscado == 'pendiente') return fechaCreacion;
    for (final cambio in historial.reversed) {
      if (cambio.estado == estadoBuscado) return cambio.fecha;
    }
    return null;
  }
}

// Apartado del cliente (GET /apartados/mis-apartados).
class Apartado {
  const Apartado({
    required this.id,
    required this.folio,
    required this.estado,
    required this.montoTotal,
    required this.montoPagado,
    required this.saldo,
    this.fechaLimite,
    this.plan,
    this.piezas = const [],
  });

  factory Apartado.fromJson(Map<String, dynamic> json) => Apartado(
    id: json['id'] as int,
    folio: json['folio'] as String? ?? '#${json['id']}',
    estado: json['estado'] as String? ?? 'pendiente_pago',
    montoTotal: _aNumero(json['monto_total']) ?? 0,
    montoPagado: _aNumero(json['monto_pagado']) ?? 0,
    saldo: _aNumero(json['saldo_pendiente']) ?? 0,
    fechaLimite: _aFecha(json['fecha_limite_liquidacion']),
    plan: json['plan_nombre'] as String?,
    piezas: (json['productos'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>().map(PiezaPedido.fromJson).toList(),
  );

  final int id;
  final String folio;
  // pendiente_pago, activo, liquidado o cancelado.
  final String estado;
  final double montoTotal;
  final double montoPagado;
  final double saldo;
  final DateTime? fechaLimite;
  final String? plan;
  final List<PiezaPedido> piezas;

  double get avance => montoTotal <= 0 ? 0 : (montoPagado / montoTotal).clamp(0, 1).toDouble();
  bool get activo => estado == 'activo' || estado == 'pendiente_pago';
}

// Resultado de confirmar una compra o un apartado.
class Confirmacion {
  const Confirmacion({required this.folio, required this.pedidoId});
  final String folio;
  final int pedidoId;
}
