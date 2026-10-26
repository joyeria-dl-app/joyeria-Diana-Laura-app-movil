// TIPO: unitaria
// ALCANCE: HU-13 · servicio de personalización: solicitar, subir foto y consultar
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/personalizacion_service_test.dart
// DATOS: backend simulado en memoria (sin red); respuestas fijas por ruta

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/models/personalizacion.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/personalizacion_service.dart';

// HU-13 · Conexión con los endpoints de personalización del backend (#47).

// Responde según la ruta y guarda qué peticiones se hicieron.
class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.respuestas, {this.status = 200});
  final Map<String, Map<String, dynamic>> respuestas;
  final int status;
  final List<RequestOptions> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    final respuesta = respuestas['${options.method} ${options.path}'] ?? {'success': false, 'message': 'Ruta no simulada'};
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

// Formas reales de las respuestas del backend (personalizacionController.ts y uploadController.ts).
const _creada = {
  'id': 12,
  'cliente_id': 5,
  'producto_id': 134,
  'detalle': 'Grabado "D & L" por dentro, letra cursiva',
  'imagen_referencia_url': 'https://res.cloudinary.com/demo/image/upload/joyeria/personalizaciones/ref.jpg',
  'estado': 'pendiente',
  'motivo_rechazo': null,
  'utilizada': false,
  'fecha_creacion': '2026-10-11T16:20:00.000Z',
  'fecha_respuesta': null,
};

const _misSolicitudes = {
  'success': true,
  'data': [
    {
      ..._creada,
      'producto_nombre': 'Anillo de promesa piedra rosa baño en rodio',
      'producto_imagen': 'https://res.cloudinary.com/demo/image/upload/anillo.jpg',
      'precio_venta': '449.50',
      'precio_personalizacion': '150.00',
    },
    {
      'id': 9,
      'producto_id': 88,
      'producto_nombre': 'Esclava de plata',
      'detalle': 'Nombre "Valentina" en la placa',
      'imagen_referencia_url': null,
      'estado': 'aprobada',
      'motivo_rechazo': null,
      'utilizada': false,
      'fecha_creacion': '2026-10-02 18:05:00',
      'fecha_respuesta': '2026-10-03 15:30:00',
      'precio_personalizacion': '0.00',
    },
    {
      'id': 7,
      'producto_id': 61,
      'producto_nombre': 'Collar corazón',
      'detalle': 'Cambiar la cadena por una más larga de 60 cm',
      'imagen_referencia_url': null,
      'estado': 'rechazada',
      'motivo_rechazo': 'La cadena de 60 cm no está disponible para este modelo.',
      'utilizada': false,
      'fecha_creacion': '2026-09-28T10:00:00.000Z',
      'fecha_respuesta': '2026-09-29T12:00:00.000Z',
    },
  ],
};

void main() {
  PersonalizacionService servicio(_AdaptadorFalso backend) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = backend;
    return PersonalizacionService(api: ApiClient(dio: dio));
  }

  group('Enviar una solicitud', () {
    test('Manda el producto, el detalle sin espacios de más y la imagen de referencia', () async {
      final backend = _AdaptadorFalso({
        'POST /personalizacion/solicitudes': {'success': true, 'data': _creada, 'dias_estimados': 2},
      });
      final enviada = await servicio(backend)
          .solicitar(productoId: 134, detalle: '  Grabado "D & L" por dentro, letra cursiva  ', imagenReferencia: _creada['imagen_referencia_url'] as String);

      expect(backend.peticiones.single.data, {
        'producto_id': 134,
        'detalle': 'Grabado "D & L" por dentro, letra cursiva',
        'imagen_referencia_url': _creada['imagen_referencia_url'],
      });
      expect(enviada.solicitud.id, 12);
      expect(enviada.solicitud.estado, EstadoSolicitud.pendiente);
      expect(enviada.diasEstimados, 2);
    });

    test('Sin imagen manda la referencia vacía y, si el backend no dice los días, toma 3', () async {
      final backend = _AdaptadorFalso({
        'POST /personalizacion/solicitudes': {'success': true, 'data': _creada},
      });
      final enviada = await servicio(backend).solicitar(productoId: 134, detalle: 'Grabado con la fecha 14/02/2027');
      expect((backend.peticiones.single.data as Map)['imagen_referencia_url'], isNull);
      expect(enviada.diasEstimados, 3);
    });

    test('Un detalle de menos de 10 o más de 1000 caracteres no llega al backend', () async {
      final backend = _AdaptadorFalso({});
      final s = servicio(backend);
      await expectLater(
        s.solicitar(productoId: 134, detalle: '  corto   '),
        throwsA(isA<PersonalizacionException>().having((e) => e.mensaje, 'mensaje', contains('al menos 10'))),
      );
      await expectLater(s.solicitar(productoId: 134, detalle: 'a' * 1001), throwsA(isA<PersonalizacionException>()));
      expect(backend.peticiones, isEmpty);
    });

    for (final mensaje in ['Este producto no admite personalización', 'Producto no disponible']) {
      test('Muestra el mensaje del backend: "$mensaje"', () async {
        final backend = _AdaptadorFalso({
          'POST /personalizacion/solicitudes': {'success': false, 'message': mensaje},
        }, status: mensaje.startsWith('Producto') ? 404 : 400);
        await expectLater(
          servicio(backend).solicitar(productoId: 134, detalle: 'Grabado con iniciales D y L'),
          throwsA(isA<PersonalizacionException>().having((e) => e.mensaje, 'mensaje', mensaje)),
        );
      });
    }

    test('Sin sesión pide iniciar sesión', () async {
      final backend = _AdaptadorFalso({
        'POST /personalizacion/solicitudes': {'success': false, 'message': 'Token requerido'},
      }, status: 401);
      await expectLater(
        servicio(backend).solicitar(productoId: 134, detalle: 'Grabado con iniciales D y L'),
        throwsA(isA<PersonalizacionException>().having((e) => e.sinSesion, 'sinSesion', isTrue)),
      );
    });

    test('Si el servidor falla avisa que revise su conexión', () async {
      final backend = _AdaptadorFalso({
        'POST /personalizacion/solicitudes': {'success': false, 'message': 'relation does not exist'},
      }, status: 500);
      await expectLater(
        servicio(backend).solicitar(productoId: 134, detalle: 'Grabado con iniciales D y L'),
        throwsA(isA<PersonalizacionException>().having((e) => e.mensaje, 'mensaje', contains('Revisa tu conexión'))),
      );
    });
  });

  group('Mis solicitudes', () {
    test('Lee producto, detalle, estado, motivo y fechas', () async {
      final backend = _AdaptadorFalso({'GET /personalizacion/mis-solicitudes': _misSolicitudes});
      final lista = await servicio(backend).misSolicitudes();

      expect(lista.map((s) => s.estado), [EstadoSolicitud.pendiente, EstadoSolicitud.aprobada, EstadoSolicitud.rechazada]);
      final pendiente = lista[0];
      expect(pendiente.productoNombre, 'Anillo de promesa piedra rosa baño en rodio');
      expect(pendiente.precioPersonalizacion, 150);
      expect(pendiente.imagenReferencia, endsWith('ref.jpg'));
      expect(pendiente.fechaCreacion, DateTime.utc(2026, 10, 11, 16, 20).toLocal());
      expect(lista[1].fechaRespuesta, DateTime.utc(2026, 10, 3, 15, 30).toLocal(), reason: 'Sin zona se toma como UTC');
      expect(lista[2].motivoRechazo, 'La cadena de 60 cm no está disponible para este modelo.');
    });

    test('Solo la aprobada y sin usar está lista para comprarse', () async {
      final backend = _AdaptadorFalso({'GET /personalizacion/mis-solicitudes': _misSolicitudes});
      final lista = await servicio(backend).misSolicitudes();
      expect(lista.map((s) => s.lista), [false, true, false]);

      const usada = SolicitudPersonalizacion(
        id: 1,
        productoId: 1,
        productoNombre: 'Anillo',
        detalle: 'Grabado',
        estado: EstadoSolicitud.aprobada,
        utilizada: true,
      );
      expect(usada.lista, isFalse);
    });

    test('Sin solicitudes devuelve la lista vacía', () async {
      final backend = _AdaptadorFalso({
        'GET /personalizacion/mis-solicitudes': {'success': true, 'data': []},
      });
      expect(await servicio(backend).misSolicitudes(), isEmpty);
    });

    test('Un estado desconocido se toma como pendiente', () {
      final s = SolicitudPersonalizacion.fromJson({..._creada, 'estado': 'en_revision'});
      expect(s.estado, EstadoSolicitud.pendiente);
    });
  });

  group('Imagen de referencia', () {
    test('Sube la foto en el campo "imagen" a la carpeta de personalizaciones y devuelve su URL', () async {
      final backend = _AdaptadorFalso({
        'POST /upload/image': {
          'success': true,
          'data': {'url': 'https://res.cloudinary.com/demo/image/upload/joyeria/personalizaciones/ref.jpg', 'publicId': 'ref'},
        },
      });
      final url = await servicio(backend).subirReferencia([1, 2, 3], 'referencia.jpg');

      expect(url, endsWith('/joyeria/personalizaciones/ref.jpg'));
      final datos = backend.peticiones.single.data as FormData;
      expect(datos.files.single.key, 'imagen');
      expect(datos.files.single.value.filename, 'referencia.jpg');
      expect({for (final c in datos.fields) c.key: c.value}, {'folder': 'joyeria/personalizaciones'});
    });

    test('Si la imagen no se acepta muestra el mensaje del backend', () async {
      final backend = _AdaptadorFalso({
        'POST /upload/image': {'success': false, 'message': 'Solo se permiten imágenes (jpeg, jpg, png, gif, webp)'},
      }, status: 400);
      await expectLater(
        servicio(backend).subirReferencia([1, 2, 3], 'documento.pdf'),
        throwsA(isA<PersonalizacionException>().having((e) => e.mensaje, 'mensaje', contains('Solo se permiten imágenes'))),
      );
    });
  });
}
