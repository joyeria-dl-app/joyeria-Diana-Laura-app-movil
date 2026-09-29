import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';

// Responde según la ruta y guarda qué peticiones se hicieron.
class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.respuestas, {this.status = 200});
  final Map<String, Map<String, dynamic>> respuestas;
  final int status;
  final List<RequestOptions> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    return ResponseBody.fromString(jsonEncode(respuestas[options.path]), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

// Forma real de un producto en /products/filter.
const _anillo = {
  'id': 58,
  'nombre': 'Anillo con circonia',
  'categoria_id': 1,
  'categoria_nombre': 'Anillos',
  'material_principal': 'Baño en rodio',
  'precio_venta': '565.47',
  'precio_oferta': null,
  'imagen_principal': null,
  'stock_actual': 3,
  'es_nuevo': true,
  'precio_promocion': '452.38',
};

void main() {
  late _AdaptadorFalso backend;

  ProductoService crear(Map<String, Map<String, dynamic>> respuestas, {int status = 200}) {
    backend = _AdaptadorFalso(respuestas, status: status);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = backend;
    return ProductoService(api: ApiClient(dio: dio));
  }

  test('Convierte los precios que llegan como texto y usa la promoción como precio final', () {
    final p = Producto.fromJson(_anillo);
    expect(p.precioVenta, 565.47);
    expect(p.precioFinal, 452.38);
    expect(p.tieneDescuento, isTrue);
    expect(p.agotado, isFalse);
    expect(p.imagen, isNull);
  });

  test('Sin promoción ni oferta el precio final es el de venta', () {
    final p = Producto.fromJson({..._anillo, 'precio_promocion': null, 'stock_actual': 0});
    expect(p.precioFinal, 565.47);
    expect(p.tieneDescuento, isFalse);
    expect(p.agotado, isTrue);
  });

  test('Pide la primera página del catálogo', () async {
    final service = crear({
      '/products/filter': {'success': true, 'data': [_anillo], 'total': 1},
    });

    final productos = await service.productos();

    expect(productos.single.nombre, 'Anillo con circonia');
    expect(backend.peticiones.single.queryParameters, {'limit': 20, 'offset': 0});
  });

  test('Filtra por categoría y pide la página indicada', () async {
    final service = crear({
      '/products/filter': {'success': true, 'data': [], 'total': 0},
    });

    await service.productos(categoriaId: 1, pagina: 2);

    expect(backend.peticiones.single.queryParameters, {'limit': 20, 'offset': 40, 'categoria_id': 1});
  });

  test('Solo muestra las categorías principales activas', () async {
    final service = crear({
      '/products/categorias': {
        'success': true,
        'data': [
          {'id': 1, 'nombre': 'Anillos', 'activo': true, 'categoria_padre_id': null, 'imagen_url': 'https://img.test/a.jpg'},
          {'id': 2, 'nombre': 'Relojes', 'activo': false, 'categoria_padre_id': null},
          {'id': 3, 'nombre': 'Anillos de compromiso', 'activo': true, 'categoria_padre_id': 1},
        ],
      },
    });

    final categorias = await service.categorias();

    expect(categorias.map((c) => c.nombre), ['Anillos']);
    expect(categorias.single.imagen, 'https://img.test/a.jpg');
  });

  test('Si el servidor falla muestra un mensaje entendible', () async {
    final service = crear({
      '/products/filter': {'success': false, 'message': 'error interno'},
    }, status: 500);

    expect(
      service.productos(),
      throwsA(isA<ProductoException>().having((e) => e.mensaje, 'mensaje', contains('No se pudo cargar el catálogo'))),
    );
  });

  test('Pide el detalle de una pieza con la foto principal y su galería', () async {
    final service = crear({
      '/products/58': {
        'success': true,
        'data': {
          ..._anillo,
          'descripcion': 'Anillo delicado con circonia.',
          'codigo': 'PROD-58',
          'peso_gramos': '4.673',
          'tiene_medidas': true,
          'medidas': 'Talla 7',
          'permite_personalizacion': true,
          'precio_personalizacion': '120.00',
          'imagen_principal': 'https://img.test/principal.jpg',
          'galeria': [
            {'id': 1, 'url_imagen': 'https://img.test/lado.jpg', 'orden': 1},
            {'id': 2, 'url_imagen': 'https://img.test/principal.jpg', 'orden': 2},
          ],
        },
      },
    });

    final detalle = await service.detalle(58);

    expect(detalle.producto.nombre, 'Anillo con circonia');
    expect(detalle.producto.personalizable, isTrue);
    expect(detalle.descripcion, 'Anillo delicado con circonia.');
    expect(detalle.pesoGramos, 4.673);
    expect(detalle.medidas, 'Talla 7');
    expect(detalle.precioPersonalizacion, 120);
    // La principal primero y sin repetirla aunque también venga en la galería.
    expect(detalle.imagenes, ['https://img.test/principal.jpg', 'https://img.test/lado.jpg']);
  });

  test('Una pieza sin fotos ni galería queda con la lista de imágenes vacía', () async {
    final service = crear({
      '/products/58': {'success': true, 'data': {..._anillo, 'galeria': null}},
    });

    final detalle = await service.detalle(58);

    expect(detalle.imagenes, isEmpty);
    expect(detalle.medidas, isNull);
  });

  test('Si la pieza ya no existe avisa que no está disponible', () async {
    final service = crear({
      '/products/999': {'success': false, 'message': 'Producto no encontrado'},
    }, status: 404);

    expect(
      service.detalle(999),
      throwsA(isA<ProductoException>().having((e) => e.mensaje, 'mensaje', 'Esta pieza ya no está disponible.')),
    );
  });
}
