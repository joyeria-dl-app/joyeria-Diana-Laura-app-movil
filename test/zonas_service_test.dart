// TIPO: unitaria
// ALCANCE: HU-16 · servicio de zonas de entrega (#60): zonas activas en el orden de la tienda y datos de la tienda, con falla parcial
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/zonas_service_test.dart
// DATOS: backend simulado en memoria (sin red); respuestas con la forma real de GET /zonas-entrega y GET /content/info-empresa

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/zonas_service.dart';

const _zonas = {
  'success': true,
  'data': [
    {'id': 3, 'nombre': 'Jaltocan', 'activo': true, 'orden': 2, 'creado_en': '2026-08-05T22:51:50.513Z'},
    {'id': 1, 'nombre': 'Huejutla', 'activo': true, 'orden': 0, 'creado_en': '2026-08-05T22:51:50.513Z'},
    {'id': 2, 'nombre': 'San Felipe', 'activo': true, 'orden': 1, 'creado_en': '2026-08-05T22:51:50.513Z'},
    {'id': 9, 'nombre': 'Zona dada de baja', 'activo': false, 'orden': 3, 'creado_en': '2026-08-05T22:51:50.513Z'},
  ],
};

const _tienda = {
  'success': true,
  'data': {
    'direccion': 'Calle Lázaro Cárdenas S/N, Col. El Zapote, C.P. 43000, Huejutla de Reyes, Hidalgo',
    'horario': 'Lunes a domingo: 9:00 a.m. – 11:00 p.m.',
    'whatsapp': '+52 771 332 1421',
  },
};

// Responde por ruta; una ruta sin respuesta contesta 500.
class _Backend implements HttpClientAdapter {
  _Backend(this.respuestas);
  final Map<String, Map<String, dynamic>> respuestas;
  final List<String> rutas = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    rutas.add(options.path);
    final r = respuestas[options.path];
    return ResponseBody.fromString(
      jsonEncode(r ?? {'success': false}),
      r == null ? 500 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ZonasService _servicio(_Backend backend) => ZonasService(
  api: ApiClient(dio: Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = backend),
);

void main() {
  test('Trae las zonas activas en el orden de la tienda y los datos de la tienda', () async {
    final backend = _Backend({'/zonas-entrega': _zonas, '/content/info-empresa': _tienda});
    final info = await _servicio(backend).entregas();

    expect(backend.rutas, containsAll(['/zonas-entrega', '/content/info-empresa']));
    expect(info.zonas!.map((z) => z.nombre), ['Huejutla', 'San Felipe', 'Jaltocan']);
    expect(info.direccion, startsWith('Calle Lázaro Cárdenas'));
    expect(info.horario, 'Lunes a domingo: 9:00 a.m. – 11:00 p.m.');
    expect(info.whatsapp, '527713321421');
  });

  test('Preguntar por mi zona abre WhatsApp con el mismo mensaje del sitio web', () async {
    final info = await _servicio(_Backend({'/zonas-entrega': _zonas, '/content/info-empresa': _tienda})).entregas();
    final enlace = info.preguntarPorMiZona!;

    expect(enlace.host, 'wa.me');
    expect(enlace.path, '/527713321421');
    expect(enlace.queryParameters['text'], 'Hola, ¿hacen entregas en mi zona?');
  });

  test('Si fallan los datos de la tienda, las zonas se muestran igual', () async {
    final info = await _servicio(_Backend({'/zonas-entrega': _zonas})).entregas();

    expect(info.zonas, hasLength(3));
    expect(info.direccion, isNull);
    expect(info.preguntarPorMiZona, isNull);
  });

  test('Si fallan las zonas, los datos de la tienda se muestran igual', () async {
    final info = await _servicio(_Backend({'/content/info-empresa': _tienda})).entregas();

    expect(info.zonas, isNull);
    expect(info.horario, isNotNull);
  });

  test('Si la tienda no tiene zonas activas, la lista queda vacía', () async {
    final info = await _servicio(
      _Backend({
        '/zonas-entrega': {'success': true, 'data': <Object>[]},
        '/content/info-empresa': _tienda,
      }),
    ).entregas();

    expect(info.zonas, isEmpty);
  });

  test('Si fallan las dos consultas avisa que no hay conexión', () async {
    expect(() => _servicio(_Backend({})).entregas(), throwsA(isA<ZonasException>().having((e) => e.mensaje, 'mensaje', contains('Revisa tu conexión'))));
  });
}
