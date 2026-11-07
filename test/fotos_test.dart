// TIPO: unitaria
// ALCANCE: #234 · armado de la URL de la foto reducida de Cloudinary
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR. flutter test test/fotos_test.dart
// DATOS: URLs con la forma real de las fotos del catálogo

import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/utils/fotos.dart';

const _original = 'https://res.cloudinary.com/dhy0gr9cu/image/upload/v1759203101/joyeria/productos/anillo-rosa.jpg';

void main() {
  test('Pide a Cloudinary la foto reducida para tarjetas', () {
    expect(fotoReducida(_original), 'https://res.cloudinary.com/dhy0gr9cu/image/upload/w_400,q_auto,f_auto/v1759203101/joyeria/productos/anillo-rosa.jpg');
  });

  test('Para el detalle pide la versión grande', () {
    expect(fotoReducida(_original, ancho: anchoFotoGrande), contains('/upload/w_1080,q_auto,f_auto/v1759203101/'));
  });

  test('Sin número de versión también agrega la reducción', () {
    expect(
      fotoReducida('https://res.cloudinary.com/dhy0gr9cu/image/upload/joyeria/productos/cadena.png'),
      'https://res.cloudinary.com/dhy0gr9cu/image/upload/w_400,q_auto,f_auto/joyeria/productos/cadena.png',
    );
  });

  test('Si la URL ya trae una transformación la deja igual', () {
    const conTransformacion = 'https://res.cloudinary.com/dhy0gr9cu/image/upload/c_fill,w_300/v1759203101/joyeria/productos/anillo-rosa.jpg';
    expect(fotoReducida(conTransformacion), conTransformacion);
  });

  test('Las URLs que no son de Cloudinary no cambian', () {
    for (final url in ['https://joyeria.example/fotos/anillo.jpg', 'https://otro.com/image/upload/anillo.jpg', 'no es una url']) {
      expect(fotoReducida(url), url);
    }
  });
}
