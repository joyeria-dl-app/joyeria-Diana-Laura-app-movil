// "Cómo llegar" (#320): Google Maps no encontraba la tienda con la dirección tal como se
// guarda ("Calle Lázaro Cárdenas S/N, Col. El Zapote, C.P. 43000, ...") y respondía que no hay
// ruta. Sin "S/N", "Col." ni "C.P." sí la ubica y traza la ruta.
String destinoParaMapas(String direccion) {
  return direccion
      .replaceAll(RegExp(r'\bS/N\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bCol(onia)?\.?\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\bC\.?\s?P\.?\s*(?=\d)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+,'), ',')
      .replaceAll(RegExp(r',\s*,'), ',')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

Uri enlaceComoLlegar(String direccion) => Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': destinoParaMapas(direccion)});
