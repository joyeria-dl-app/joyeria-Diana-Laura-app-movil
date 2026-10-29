// Fotos reducidas de Cloudinary (#234). Las piezas se suben en su tamaño original (50–113 KB) y en
// las tarjetas se ven pequeñas; Cloudinary entrega la misma foto ya reducida si se le pide en la URL.

// Ancho en píxeles de la foto para tarjetas y miniaturas (catálogo, carrito, favoritos, pedidos).
const int anchoFotoChica = 400;

// Ancho de la foto grande del detalle: nítida a pantalla completa sin bajar el original.
const int anchoFotoGrande = 1080;

final _transformacion = RegExp(r'^[a-z]{1,3}_[^/]*$');

// Devuelve la URL de Cloudinary con la foto reducida a [ancho] y en el formato y la calidad que
// mejor convengan al teléfono. Las URLs que no son de Cloudinary, o que ya traen una
// transformación, se devuelven igual.
String fotoReducida(String url, {int ancho = anchoFotoChica}) {
  const marca = '/image/upload/';
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'res.cloudinary.com') return url;
  final i = url.indexOf(marca);
  if (i < 0) return url;
  final resto = url.substring(i + marca.length);
  final primero = resto.split('/').first;
  if (_transformacion.hasMatch(primero)) return url;
  return '${url.substring(0, i + marca.length)}w_$ancho,q_auto,f_auto/$resto';
}
