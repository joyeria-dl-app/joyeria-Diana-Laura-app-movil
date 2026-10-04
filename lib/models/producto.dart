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
    this.personalizable = false,
    this.promedioResenas = 0,
    this.totalResenas = 0,
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
    personalizable: json['permite_personalizacion'] as bool? ?? false,
    promedioResenas: _aNumero(json['promedio_resenas']) ?? 0,
    totalResenas: json['total_resenas'] as int? ?? 0,
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
  final bool personalizable;
  // Calificación de las reseñas del sitio web; 0 mientras la pieza no tenga.
  final double promedioResenas;
  final int totalResenas;

  // Mismo criterio que el sitio web: la promoción vigente gana a la oferta.
  double get precioFinal => precioPromocion ?? precioOferta ?? precioVenta;
  bool get tieneDescuento => precioFinal < precioVenta;
  bool get agotado => stock <= 0;
}

class Categoria {
  const Categoria({required this.id, required this.nombre, this.imagen});

  factory Categoria.fromJson(Map<String, dynamic> json) =>
      Categoria(id: json['id'] as int, nombre: json['nombre'] as String? ?? '', imagen: json['imagen_url'] as String?);

  final int id;
  final String nombre;
  final String? imagen;

  // En el panel algunas se capturaron en minúsculas ("esclavas").
  String get nombreVisible => nombre.isEmpty ? nombre : nombre[0].toUpperCase() + nombre.substring(1);
}

// Lo que muestra la pantalla de detalle (GET /products/:id).
class DetalleProducto {
  const DetalleProducto({
    required this.producto,
    this.descripcion,
    this.codigo,
    this.genero,
    this.pesoGramos,
    this.medidas,
    this.precioPersonalizacion = 0,
    this.imagenes = const [],
  });

  factory DetalleProducto.fromJson(Map<String, dynamic> json) {
    // La foto principal va primero y luego la galería, sin repetir.
    final imagenes = <String>[if (json['imagen_principal'] case final String url when url.isNotEmpty) url];
    for (final foto in (json['galeria'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>()) {
      final url = foto['url_imagen'] as String?;
      if (url != null && url.isNotEmpty && !imagenes.contains(url)) imagenes.add(url);
    }
    return DetalleProducto(
      producto: Producto.fromJson(json),
      descripcion: json['descripcion'] as String?,
      codigo: json['codigo'] as String?,
      genero: json['genero'] as String?,
      pesoGramos: _aNumero(json['peso_gramos']),
      medidas: json['tiene_medidas'] == true ? json['medidas'] as String? : null,
      precioPersonalizacion: _aNumero(json['precio_personalizacion']) ?? 0,
      imagenes: imagenes,
    );
  }

  final Producto producto;
  final String? descripcion;
  final String? codigo;
  final String? genero;
  final double? pesoGramos;
  final String? medidas;
  final double precioPersonalizacion;
  final List<String> imagenes;
}
