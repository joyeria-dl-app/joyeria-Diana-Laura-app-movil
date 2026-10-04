import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';

// Responde lo mismo a todas las rutas y guarda qué peticiones se hicieron.
class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.respuesta, {this.status = 200});
  final Map<String, dynamic> respuesta;
  final int status;
  final List<RequestOptions> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    return ResponseBody.fromString(jsonEncode(respuesta), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

// Forma real de un renglón en GET /favoritos.
const _anillo = {
  'id': 14,
  'fecha_agregado': '2026-10-04T10:00:00.000Z',
  'producto_id': 58,
  'nombre': 'Anillo flor rosa',
  'precio_venta': '890.00',
  'precio_oferta': null,
  'imagen_principal': 'https://res.cloudinary.com/x/anillo.jpg',
  'stock_actual': 0,
  'es_nuevo': false,
  'permite_personalizacion': true,
  'categoria_nombre': 'Anillos',
  'precio_promocion': '712.00',
};

void main() {
  late _AdaptadorFalso backend;

  FavoritoService crear(Map<String, dynamic> respuesta, {int status = 200}) {
    backend = _AdaptadorFalso(respuesta, status: status);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = backend;
    return FavoritoService(api: ApiClient(dio: dio));
  }

  test('Consulta la lista con el id de la pieza, no el del favorito', () async {
    final lista = await crear({
      'success': true,
      'data': [_anillo],
    }).lista();

    expect(backend.peticiones.single.path, '/favoritos');
    final pieza = lista.single;
    expect(pieza.id, 58);
    expect(pieza.nombre, 'Anillo flor rosa');
    expect(pieza.categoriaNombre, 'Anillos');
    expect(pieza.precioFinal, 712);
    expect(pieza.agotado, isTrue);
    expect(pieza.personalizable, isTrue);
  });

  test('Sin favoritos regresa la lista vacía', () async {
    final lista = await crear({'success': true, 'data': []}).lista();
    expect(lista, isEmpty);
  });

  test('Marcar una pieza la guarda y avisa que quedó como favorita', () async {
    final favorita = await crear({'success': true, 'favorito': true, 'message': 'Agregado a favoritos'}).alternar(58);

    final p = backend.peticiones.single;
    expect([p.method, p.path, p.data], ['POST', '/favoritos/toggle', {'producto_id': 58}]);
    expect(favorita, isTrue);
  });

  test('Tocar otra vez la quita de favoritos', () async {
    final favorita = await crear({'success': true, 'favorito': false, 'message': 'Eliminado de favoritos'}).alternar(58);
    expect(favorita, isFalse);
  });

  test('Pregunta si una pieza ya es favorita', () async {
    final favorita = await crear({'success': true, 'favorito': true}).esFavorito(58);

    expect(backend.peticiones.single.path, '/favoritos/check/58');
    expect(favorita, isTrue);
  });

  test('Sin sesión avisa que hay que iniciar sesión', () async {
    await expectLater(
      crear({'success': false, 'message': 'Token de acceso requerido'}, status: 401).alternar(58),
      throwsA(isA<FavoritoException>().having((e) => e.sinSesion, 'sinSesion', isTrue)),
    );
  });

  test('Si el servidor falla muestra un mensaje entendible', () async {
    await expectLater(
      crear({'success': false, 'message': 'relation "favoritos" does not exist'}, status: 500).lista(),
      throwsA(isA<FavoritoException>()
          .having((e) => e.mensaje, 'mensaje', contains('Revisa tu conexión'))
          .having((e) => e.sinSesion, 'sinSesion', isFalse)),
    );
  });
}
