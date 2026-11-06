// TIPO: unitaria
// ALCANCE: #272 · renovar la sesión ante un 401 y Certificate Pinning del cliente HTTP
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR. flutter test test/sesion_seguridad_test.dart
// DATOS: backend y Firebase simulados en memoria. Las pruebas de pinning se conectan a github.com (otra
//        autoridad, debe rechazarse) y al backend real de Render (debe aceptarse).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/models/usuario.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/auth_service.dart';
import 'package:joyeria_diana_laura/services/certificados.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

// Backend falso: /carrito responde 401 con un token viejo y 200 con el token nuevo.
class _Backend implements HttpClientAdapter {
  _Backend({this.tokenValido = 'token-nuevo'});
  final String tokenValido;
  final List<RequestOptions> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    final (status, cuerpo) = switch (options.path) {
      '/auth/login/movil' => (200, {
        'success': true,
        'data': {
          'token': tokenValido,
          'user': {'email': 'clienta@prueba.mx', 'nombre': 'Clienta', 'rol': 'cliente'},
        },
      }),
      '/auth/login' => (401, {'success': false}),
      _ when options.headers['Authorization'] == 'Bearer $tokenValido' => (200, {'success': true, 'data': <Object>[]}),
      _ => (401, {'success': false, 'message': 'Token expirado'}),
    };
    return ResponseBody.fromString(
      jsonEncode(cuerpo),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// Servicio de tokens de Firebase falso: cambia el refreshToken por un ID token nuevo.
class _Tokens implements HttpClientAdapter {
  _Tokens({this.acepta = true});
  final bool acepta;
  final List<RequestOptions> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    final cuerpo = acepta
        ? {'id_token': 'id-token-nuevo', 'refresh_token': 'renovacion-nueva'}
        : {
            'error': {'message': 'TOKEN_EXPIRED'},
          };
    return ResponseBody.fromString(
      jsonEncode(cuerpo),
      acepta ? 200 : 400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _usuario = Usuario(email: 'clienta@prueba.mx', nombre: 'Clienta', rol: 'cliente');

void main() {
  group('Renovar la sesión ante un 401', () {
    late MemorySessionStorage storage;
    late _Backend backend;
    late _Tokens tokens;
    late ApiClient api;
    late int vencidas;

    Future<void> preparar({bool firebaseAcepta = true, bool conRenovacion = true}) async {
      storage = MemorySessionStorage();
      await storage.guardar('token-viejo', _usuario);
      if (conRenovacion) await storage.guardarRenovacion('renovacion-vieja');
      backend = _Backend();
      tokens = _Tokens(acepta: firebaseAcepta);
      api = ApiClient(dio: Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = backend, storage: storage);
      final auth = AuthService(
        api: api,
        storage: storage,
        tokenDio: Dio(BaseOptions(baseUrl: 'https://tokens.test'))..httpClientAdapter = tokens,
        apiKey: 'clave-de-prueba',
      );
      vencidas = 0;
      auth.alVencerSesion(() => vencidas++);
    }

    test('Un token vencido se renueva con Firebase y la petición se repite sin que se note', () async {
      await preparar();

      final respuesta = await api.dio.get('/carrito');

      expect(respuesta.statusCode, 200);
      expect(backend.peticiones.map((p) => p.path), ['/carrito', '/auth/login/movil', '/carrito']);
      expect(backend.peticiones.last.headers['Authorization'], 'Bearer token-nuevo');
      expect(tokens.peticiones.single.data, {'grant_type': 'refresh_token', 'refresh_token': 'renovacion-vieja'});
      expect(await storage.leerToken(), 'token-nuevo');
      expect(await storage.leerRenovacion(), 'renovacion-nueva');
      expect(await storage.leerUsuario(), isNotNull, reason: 'La clienta sigue con su sesión');
      expect(vencidas, 0);
    });

    test('Varias peticiones con 401 al mismo tiempo comparten una sola renovación', () async {
      await preparar();

      await Future.wait([api.dio.get('/carrito'), api.dio.get('/favoritos'), api.dio.get('/auth/profile')]);

      expect(tokens.peticiones, hasLength(1));
      expect(backend.peticiones.where((p) => p.path == '/auth/login/movil'), hasLength(1));
    });

    test('Si Firebase no renueva, se borra la sesión y se avisa para ir a iniciar sesión', () async {
      await preparar(firebaseAcepta: false);

      await expectLater(api.dio.get('/carrito'), throwsA(isA<DioException>()));

      expect(await storage.leerToken(), isNull);
      expect(await storage.leerRenovacion(), isNull);
      expect(vencidas, 1);
    });

    test('Sin refreshToken guardado (sesión de antes de #272) también lleva a iniciar sesión', () async {
      await preparar(conRenovacion: false);

      await expectLater(api.dio.get('/carrito'), throwsA(isA<DioException>()));

      expect(tokens.peticiones, isEmpty);
      expect(vencidas, 1);
    });

    test('Un 401 al iniciar sesión (contraseña incorrecta) no intenta renovar', () async {
      await preparar();

      await expectLater(api.dio.post('/auth/login', data: {}), throwsA(isA<DioException>()));

      expect(tokens.peticiones, isEmpty);
      expect(await storage.leerToken(), 'token-viejo');
    });

    test('Al iniciar sesión se guarda el refreshToken de Firebase', () async {
      final guardado = MemorySessionStorage();
      final firebase = _FirebaseLogin();
      final auth = AuthService(
        api: ApiClient(dio: Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = _Backend(tokenValido: 'token-login')),
        storage: guardado,
        firebaseDio: Dio(BaseOptions(baseUrl: 'https://firebase.test'))..httpClientAdapter = firebase,
        apiKey: 'clave-de-prueba',
      );

      await auth.iniciarSesion('clienta@prueba.mx', 'secreta');

      expect(firebase.peticiones.single.path, '/accounts:signInWithPassword');
      expect(await guardado.leerToken(), 'token-login');
      expect(await guardado.leerRenovacion(), 'renovacion-de-login');
    });
  });

  group('Certificate Pinning', () {
    test('Las autoridades fijadas coinciden con su huella SHA-256 publicada', () {
      for (final c in certificadosFijados) {
        expect(huellaSha256(c.pem), c.sha256, reason: c.nombre);
      }
    });

    test('Si el certificado guardado se altera, la app no confía en nada', () {
      final original = certificadosFijados.first;
      // Se cambia un carácter del certificado, como si alguien reemplazara la autoridad en el código.
      final alterado = CertificadoFijado('Alterado', original.sha256, original.pem.replaceFirst('MIIC', 'MIIB'));
      expect(() => contextoFijado([alterado]), throwsStateError);
    });

    // Un sitio real con un certificado válido, pero de otra autoridad (Sectigo, USERTrust): un
    // teléfono normal lo acepta y la app debe rechazarlo, como haría con un proxy que intercepta.
    Dio cliente(HttpClient Function() crear) =>
        Dio(BaseOptions(baseUrl: 'https://github.com', receiveTimeout: const Duration(seconds: 30)))
          ..httpClientAdapter = IOHttpClientAdapter(createHttpClient: crear);

    test('El cliente de la app rechaza un certificado válido de otra autoridad', () async {
      await expectLater(
        cliente(clienteConPinning).get('/'),
        throwsA(isA<DioException>().having((e) => e.error, 'error', isA<HandshakeException>())),
      );
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('Control: un cliente sin pinning sí se conecta a ese sitio', () async {
      final respuesta = await cliente(HttpClient.new).get('/');
      expect(respuesta.statusCode, 200);
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('El cliente de la app sí se conecta al backend real de Render', () async {
      final render = Dio(BaseOptions(baseUrl: 'https://joyeria-diana-laura-nqnq.onrender.com/api', receiveTimeout: const Duration(seconds: 90)))
        ..httpClientAdapter = IOHttpClientAdapter(createHttpClient: clienteConPinning);
      final respuesta = await render.get('/products/categorias');
      expect(respuesta.statusCode, 200);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

// Firebase al iniciar sesión: entrega ID token y refreshToken.
class _FirebaseLogin implements HttpClientAdapter {
  final List<RequestOptions> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    return ResponseBody.fromString(
      jsonEncode({'idToken': 'id-token', 'refreshToken': 'renovacion-de-login'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
