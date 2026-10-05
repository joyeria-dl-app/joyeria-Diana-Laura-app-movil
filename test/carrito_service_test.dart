import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';

// Responde lo mismo a todas las rutas y guarda qué peticiones se hicieron.
class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.respuesta, {this.status = 200});
  final Map<String, dynamic> respuesta;
  final int status;
  final List<RequestOptions> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    return ResponseBody.fromString(
      jsonEncode(respuesta),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// Forma real de un renglón en GET /carrito.
const _anillo = {
  'id': 301,
  'usuario_id': 12,
  'producto_id': 58,
  'cantidad': 2,
  'talla_medida': 'Talla 7',
  'producto_nombre': 'Anillo corazón',
  'producto_imagen': 'https://res.cloudinary.com/x/anillo.jpg',
  'precio_venta': '1250.00',
  'precio_oferta': null,
  'precio_promocion': '1000.00',
  'stock_actual': 3,
  'categoria_nombre': 'Anillos',
};

void main() {
  late _AdaptadorFalso backend;

  CarritoService crear(Map<String, dynamic> respuesta, {int status = 200}) {
    backend = _AdaptadorFalso(respuesta, status: status);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = backend;
    return CarritoService(api: ApiClient(dio: dio));
  }

  test('Consulta el carrito con sus piezas y el total del backend', () async {
    final servicio = crear({
      'success': true,
      'data': {
        'items': [_anillo],
        'total': 2000,
        'count': 1,
        'promo_no_aplica': null,
      },
    });

    final carrito = await servicio.obtener();

    expect(backend.peticiones.single.path, '/carrito');
    expect(carrito.items.single.nombre, 'Anillo corazón');
    expect(carrito.items.single.talla, 'Talla 7');
    expect(carrito.items.single.precioFinal, 1000);
    expect(carrito.piezas, 2);
    expect(carrito.total, 2000);
    expect(carrito.vacio, isFalse);
  });

  test('Sin promoción el precio de la pieza es el de venta', () async {
    final servicio = crear({
      'success': true,
      'data': {
        'items': [
          {..._anillo, 'precio_promocion': null, 'cantidad': 3},
        ],
        'total': 3750,
      },
    });

    final item = (await servicio.obtener()).items.single;
    expect(item.precioFinal, 1250);
    expect(item.puedeAumentar, isFalse);
  });

  test('Un carrito sin piezas queda vacío', () async {
    final carrito = await crear({
      'success': true,
      'data': {'items': [], 'total': 0, 'count': 0},
    }).obtener();

    expect(carrito.vacio, isTrue);
    expect(carrito.total, 0);
  });

  test('Agrega una pieza con su cantidad y talla', () async {
    await crear({'success': true, 'message': 'Agregado al carrito'}).agregar(58, cantidad: 2, talla: 'Talla 7');

    final p = backend.peticiones.single;
    expect(p.method, 'POST');
    expect(p.path, '/carrito');
    expect(p.data, {'producto_id': 58, 'cantidad': 2, 'talla_medida': 'Talla 7'});
  });

  test('Sin talla no la manda al backend', () async {
    await crear({'success': true}).agregar(58);
    expect(backend.peticiones.single.data, {'producto_id': 58, 'cantidad': 1});
  });

  test('Cambia la cantidad, quita una pieza y vacía el carrito', () async {
    final servicio = crear({'success': true});

    await servicio.cambiarCantidad(301, 3);
    await servicio.quitar(301);
    await servicio.vaciar();

    final p = backend.peticiones;
    expect(
      [p[0].method, p[0].path, p[0].data],
      [
        'PUT',
        '/carrito/301',
        {'cantidad': 3},
      ],
    );
    expect([p[1].method, p[1].path], ['DELETE', '/carrito/301']);
    expect([p[2].method, p[2].path], ['DELETE', '/carrito/vaciar']);
  });

  test('Cuenta las piezas para el ícono de la barra', () async {
    final total = await crear({
      'success': true,
      'data': {'count': 4},
    }).contar();
    expect(total, 4);
    expect(backend.peticiones.single.path, '/carrito/count');
  });

  test('Sin sesión avisa que hay que iniciar sesión', () async {
    final servicio = crear({'success': false, 'message': 'No autenticado'}, status: 401);

    await expectLater(servicio.obtener(), throwsA(isA<CarritoException>().having((e) => e.sinSesion, 'sinSesion', isTrue)));
  });

  test('Si no hay existencias muestra el mensaje del backend', () async {
    final servicio = crear({'success': false, 'message': 'Stock insuficiente'}, status: 400);

    await expectLater(servicio.agregar(58, cantidad: 9), throwsA(isA<CarritoException>().having((e) => e.mensaje, 'mensaje', 'Stock insuficiente')));
  });

  test('Si el servidor falla muestra un mensaje entendible', () async {
    final servicio = crear({'success': false, 'message': 'relation "carrito" does not exist'}, status: 500);

    await expectLater(
      servicio.obtener(),
      throwsA(isA<CarritoException>().having((e) => e.mensaje, 'mensaje', contains('Revisa tu conexión')).having((e) => e.sinSesion, 'sinSesion', isFalse)),
    );
  });
}
