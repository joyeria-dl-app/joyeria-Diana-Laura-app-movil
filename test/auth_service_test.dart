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
  late _AdaptadorFalso backendFalso;
  late _AdaptadorFalso firebaseFalso;

  AuthService crear(Map<String, _Respuesta> firebase, Map<String, _Respuesta> backend) {
    storage = MemorySessionStorage();
    final dioBackend = Dio(BaseOptions(baseUrl: 'https://api.test'));
    backendFalso = _AdaptadorFalso(backend);
    dioBackend.httpClientAdapter = backendFalso;
    firebaseFalso = _AdaptadorFalso(firebase);
    final dioFirebase = Dio(BaseOptions(baseUrl: 'https://firebase.test'))..httpClientAdapter = firebaseFalso;
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

  test('Sin "Recordarme" la sesión no se conserva al volver a abrir la app', () async {
    final service = crear(
      {'/accounts:signInWithPassword': const _Respuesta(200, {'idToken': 'id-token'})},
      {
        '/auth/login/movil': const _Respuesta(200, {
          'success': true,
          'data': {'token': 'jwt-sesion', 'user': {'email': 'a@b.com', 'nombre': 'A', 'rol': 'cliente'}},
        }),
      },
    );
    await service.iniciarSesion('a@b.com', 'x', recordar: false);
    expect(await storage.leerToken(), 'jwt-sesion');

    expect(await service.sesionGuardada(), isNull);
    expect(await storage.leerToken(), isNull);
  });

  group('Registro', () {
    const firebaseOk = {
      '/accounts:signUp': _Respuesta(200, {'idToken': 'token-nuevo'}),
      '/accounts:update': _Respuesta(200, {}),
      '/accounts:sendOobCode': _Respuesta(200, {}),
    };
    const backendOk = {
      '/auth/sync-user/movil': _Respuesta(200, {'success': true}),
      '/security/set-security-question': _Respuesta(200, {'success': true}),
    };

    Future<void> registrar(AuthService s) => s.registrarse(
          nombre: 'Ana Martínez',
          email: ' ana@correo.com ',
          password: 'Clave1234',
          tipoPregunta: '2',
          respuesta: 'Rosa',
        );

    test('Crea la cuenta, envía la verificación y guarda la pregunta secreta con el token', () async {
      final service = crear(firebaseOk, backendOk);

      await registrar(service);

      expect(firebaseFalso.peticiones.map((p) => p.path),
          ['/accounts:signUp', '/accounts:update', '/accounts:sendOobCode']);
      expect(firebaseFalso.peticiones[2].data, {'requestType': 'VERIFY_EMAIL', 'idToken': 'token-nuevo'});
      expect(backendFalso.peticiones.map((p) => p.path), ['/auth/sync-user/movil', '/security/set-security-question']);
      expect(backendFalso.peticiones[1].data, {
        'email': 'ana@correo.com',
        'questionType': '2',
        'customQuestion': '',
        'answer': 'Rosa',
        'idToken': 'token-nuevo',
      });
      expect(await storage.leerToken(), isNull, reason: 'no se abre sesión hasta verificar el correo');
    });

    test('Si el correo ya existe muestra un mensaje claro y no llama al backend', () async {
      final service = crear({
        '/accounts:signUp': const _Respuesta(400, {
          'error': {'message': 'EMAIL_EXISTS'},
        }),
      }, backendOk);

      await expectLater(
        registrar(service),
        throwsA(isA<AuthException>().having((e) => e.mensaje, 'mensaje', contains('ya tiene una cuenta'))),
      );
      expect(backendFalso.peticiones, isEmpty);
    });
  });
}
