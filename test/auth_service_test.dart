import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/auth_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

class _Respuesta {
  const _Respuesta(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
}

// Responde según la ruta y guarda qué peticiones se hicieron.
class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.respuestas);
  final Map<String, _Respuesta> respuestas;
  final List<RequestOptions> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    final r = respuestas[options.path]!;
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MemorySessionStorage storage;

  AuthService crear(Map<String, _Respuesta> firebase, Map<String, _Respuesta> backend) {
    storage = MemorySessionStorage();
    final dioBackend = Dio(BaseOptions(baseUrl: 'https://api.test'));
    final adaptador = _AdaptadorFalso(backend);
    dioBackend.httpClientAdapter = adaptador;
    final dioFirebase = Dio(BaseOptions(baseUrl: 'https://firebase.test'))..httpClientAdapter = _AdaptadorFalso(firebase);
    return AuthService(
      api: ApiClient(dio: dioBackend),
      storage: storage,
      firebaseDio: dioFirebase,
      apiKey: 'clave-de-prueba',
    );
  }

  test('Con contraseña correcta guarda el token y el usuario', () async {
    final service = crear(
      {'/accounts:signInWithPassword': const _Respuesta(200, {'idToken': 'id-token'})},
      {
        '/auth/login/movil': const _Respuesta(200, {
          'success': true,
          'data': {
            'token': 'jwt-sesion',
            'user': {'email': 'ana@correo.com', 'nombre': 'Ana', 'rol': 'cliente'},
          },
        }),
      },
    );

    final usuario = await service.iniciarSesion(' ana@correo.com ', 'secreta');

    expect(usuario.nombre, 'Ana');
    expect(await storage.leerToken(), 'jwt-sesion');
    expect((await service.sesionGuardada())?.email, 'ana@correo.com');
  });

  test('Con contraseña incorrecta registra el intento y muestra los intentos restantes', () async {
    final service = crear(
      {
        '/accounts:signInWithPassword': const _Respuesta(400, {
          'error': {'message': 'INVALID_LOGIN_CREDENTIALS'},
        }),
      },
      {'/auth/login': const _Respuesta(401, {'success': false, 'remainingAttempts': 2})},
    );

    await expectLater(
      service.iniciarSesion('ana@correo.com', 'mala'),
      throwsA(isA<AuthException>().having((e) => e.mensaje, 'mensaje', contains('Te quedan 2 intentos'))),
    );
    expect(await storage.leerToken(), isNull);
  });

  test('Con la cuenta bloqueada muestra el mensaje del backend', () async {
    final service = crear(
      {'/accounts:signInWithPassword': const _Respuesta(200, {'idToken': 'id-token'})},
      {'/auth/login/movil': const _Respuesta(423, {'success': false, 'message': 'Cuenta bloqueada. Intenta en 10 min.'})},
    );

    await expectLater(
      service.iniciarSesion('ana@correo.com', 'secreta'),
      throwsA(isA<AuthException>().having((e) => e.mensaje, 'mensaje', 'Cuenta bloqueada. Intenta en 10 min.')),
    );
  });

  test('Cerrar sesión borra el token guardado', () async {
    final service = crear(
      {'/accounts:signInWithPassword': const _Respuesta(200, {'idToken': 'id-token'})},
      {
        '/auth/login/movil': const _Respuesta(200, {
          'success': true,
          'data': {'token': 'jwt-sesion', 'user': {'email': 'a@b.com', 'nombre': 'A', 'rol': 'cliente'}},
        }),
      },
    );
    await service.iniciarSesion('a@b.com', 'x');

    await service.cerrarSesion();

    expect(await service.sesionGuardada(), isNull);
  });
}
