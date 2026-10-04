// PostgreSQL envía los precios (numeric) como texto, por ejemplo "565.47".
double? _aNumero(Object? valor) => switch (valor) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

// Una pieza dentro del carrito (GET /carrito).
class ItemCarrito {
  const ItemCarrito({
    required this.id,
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioVenta,
    this.precioOferta,
    this.precioPromocion,
    this.imagen,
    this.talla,
    this.categoriaNombre,
    this.stock = 0,
  });

  factory ItemCarrito.fromJson(Map<String, dynamic> json) => ItemCarrito(
        id: json['id'] as int,
        productoId: json['producto_id'] as int,
        nombre: json['producto_nombre'] as String? ?? '',
        cantidad: json['cantidad'] as int? ?? 1,
        precioVenta: _aNumero(json['precio_venta']) ?? 0,
        precioOferta: _aNumero(json['precio_oferta']),
        precioPromocion: _aNumero(json['precio_promocion']),
        imagen: json['producto_imagen'] as String?,
        talla: json['talla_medida'] as String?,
        categoriaNombre: json['categoria_nombre'] as String?,
        stock: json['stock_actual'] as int? ?? 0,
      );

  // Id del renglón en el carrito; es el que piden cambiar cantidad y quitar.
  final int id;
  final int productoId;
  final String nombre;
  final int cantidad;
  final double precioVenta;
  final double? precioOferta;
  final double? precioPromocion;
  final String? imagen;
  final String? talla;
  final String? categoriaNombre;
  final int stock;

  // Mismo criterio que el sitio web: la promoción vigente gana a la oferta.
  double get precioFinal => precioPromocion ?? precioOferta ?? precioVenta;
  bool get puedeAumentar => cantidad < stock;
}

class Carrito {
  const Carrito({this.items = const [], this.total = 0});

  factory Carrito.fromJson(Map<String, dynamic> json) => Carrito(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((i) => ItemCarrito.fromJson(i as Map<String, dynamic>))
            .toList(),
        total: _aNumero(json['total']) ?? 0,
      );

  final List<ItemCarrito> items;
  // Total calculado por el backend, el mismo que muestra el sitio web.
  final double total;

  bool get vacio => items.isEmpty;
  int get piezas => items.fold(0, (suma, i) => suma + i.cantidad);
}
