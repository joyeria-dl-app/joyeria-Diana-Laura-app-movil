// Precio como en los bocetos: "$1,250" o "$565.47" (sin decimales si son cero).
String formatoPrecio(double precio) {
  final centavos = (precio * 100).round();
  final enteros = (centavos ~/ 100).toString();
  final conComas = enteros.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final resto = centavos % 100;
  return resto == 0 ? '\$$conComas' : '\$$conComas.${resto.toString().padLeft(2, '0')}';
}
