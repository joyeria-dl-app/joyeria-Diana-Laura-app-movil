// PostgreSQL envía los precios (numeric) como texto, por ejemplo "565.47".
double? _aNumero(Object? valor) => switch (valor) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };

class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    required this.precioVenta,
    this.precioOferta,
    this.precioPromocion,
    this.imagen,
    this.categoriaId,
    this.categoriaNombre,
    this.material,
    this.stock = 0,
    this.esNuevo = false,
  });

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        precioVenta: _aNumero(json['precio_venta']) ?? 0,
        precioOferta: _aNumero(json['precio_oferta']),
        precioPromocion: _aNumero(json['precio_promocion']),
        imagen: json['imagen_principal'] as String?,
        categoriaId: json['categoria_id'] as int?,
        categoriaNombre: json['categoria_nombre'] as String?,
        material: json['material_principal'] as String?,
        stock: json['stock_actual'] as int? ?? 0,
        esNuevo: json['es_nuevo'] as bool? ?? false,
      );

  final int id;
  final String nombre;
  final double precioVenta;
  final double? precioOferta;
  final double? precioPromocion;
  final String? imagen;
  final int? categoriaId;
  final String? categoriaNombre;
  final String? material;
  final int stock;
  final bool esNuevo;

  // Mismo criterio que el sitio web: la promoción vigente gana a la oferta.
  double get precioFinal => precioPromocion ?? precioOferta ?? precioVenta;
  bool get tieneDescuento => precioFinal < precioVenta;
  bool get agotado => stock <= 0;
}

class Categoria {
  const Categoria({required this.id, required this.nombre, this.imagen});

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
        id: json['id'] as int,
        nombre: json['nombre'] as String? ?? '',
        imagen: json['imagen_url'] as String?,
      );

  final int id;
  final String nombre;
  final String? imagen;
}
