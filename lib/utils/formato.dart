// Precio como en los bocetos: "$1,250" o "$565.47" (sin decimales si son cero).
String formatoPrecio(double precio) {
  final centavos = (precio * 100).round();
  final enteros = (centavos ~/ 100).toString();
  final conComas = enteros.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final resto = centavos % 100;
  return resto == 0 ? '\$$conComas' : '\$$conComas.${resto.toString().padLeft(2, '0')}';
}

// Precio siempre con centavos, como en el resumen del carrito: "$1,790.00".
String formatoPrecioCompleto(double precio) {
  final centavos = (precio * 100).round();
  final enteros = (centavos ~/ 100).toString();
  final conComas = enteros.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '\$$conComas.${(centavos % 100).toString().padLeft(2, '0')}';
}

// Calificación de reseñas como en los bocetos: "4.9", o "0" si aún no hay reseñas.
String formatoCalificacion(double promedio) => promedio == 0 ? '0' : promedio.toStringAsFixed(1);
