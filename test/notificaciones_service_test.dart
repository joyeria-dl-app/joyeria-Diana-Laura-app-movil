// TIPO: unitaria
// ALCANCE: HU-15 · registro del teléfono para las notificaciones del pedido (#55): permiso, token, cambio de token y cierre de sesión
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/notificaciones_service_test.dart
// DATOS: backend y Firebase Cloud Messaging simulados en memoria (sin red); token de ejemplo

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/models/usuario.dart';
import 'package:joyeria_diana_laura/providers/auth_provider.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/auth_service.dart';
import 'package:joyeria_diana_laura/services/notificaciones_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

const _token = 'fcm-token-del-telefono-de-ana-0001';

class _MensajeriaFalsa implements MensajeriaPush {
  bool permiso = true;
  String? actual = _token;
  int borrados = 0;
  final _nuevos = StreamController<String>.broadcast();

  void cambiarToken(String nuevo) {
    actual = nuevo;
    _nuevos.add(nuevo);
  }

  @override
  Future<bool> pedirPermiso() async => permiso;

  @override
  Future<String?> token() async => actual;

  @override
  Stream<String> get tokenNuevo => _nuevos.stream;

  @override
  Future<void> borrarToken() async => borrados++;
}

// Backend en memoria: guarda cada petición con su cuerpo y si llevó la sesión.
class _Backend implements HttpClientAdapter {
  final List<({String ruta, Map<String, dynamic> cuerpo, bool conSesion})> peticiones = [];
  int status = 200;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add((
      ruta: '${options.method} ${options.path}',
      cuerpo: Map<String, dynamic>.from(options.data as Map? ?? const {}),
      conSesion: options.headers['Authorization'] == 'Bearer token-de-ana',
    ));
    return ResponseBody.fromString(
      jsonEncode({'success': status == 200}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// Inicio de sesión simulado: guarda la sesión como lo hace el real.
class _AuthFalso extends AuthService {
  _AuthFalso(this._storage, ApiClient api) : super(api: api, storage: _storage);
  final MemorySessionStorage _storage;
  static const _ana = Usuario(email: 'ana@correo.com', nombre: 'Ana', rol: 'cliente');

  @override
  Future<Usuario> iniciarSesion(String email, String password, {bool recordar = true}) async {
    await _storage.guardar('token-de-ana', _ana);
    return _ana;
  }

  @override
  Future<void> cerrarSesion() => _storage.borrar();
}

// Deja terminar las peticiones que la app manda sin esperar (registro en segundo plano).
Future<void> _esperar() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late _Backend backend;
  late _MensajeriaFalsa mensajeria;
  late MemorySessionStorage storage;
  late ApiClient api;

  setUp(() async {
    backend = _Backend();
    mensajeria = _MensajeriaFalsa();
    storage = MemorySessionStorage();
    api = ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = backend,
      storage: storage,
    );
  });

  group('Servicio', () {
    setUp(() => storage.guardar('token-de-ana', const Usuario(email: 'ana@correo.com', nombre: 'Ana', rol: 'cliente')));

    test('Con permiso registra el token del teléfono en el backend con la sesión', () async {
      final servicio = NotificacionesService(api: api, mensajeria: mensajeria);
      await servicio.activar();

      expect(backend.peticiones.single.ruta, 'POST /notificaciones/dispositivo');
      expect(backend.peticiones.single.cuerpo, {'token': _token, 'plataforma': 'android'});
      expect(backend.peticiones.single.conSesion, isTrue);
      expect(servicio.tokenRegistrado, _token);
    });

    test('Sin permiso de notificaciones no registra nada', () async {
      mensajeria.permiso = false;
      final servicio = NotificacionesService(api: api, mensajeria: mensajeria);
      await servicio.activar();

      expect(backend.peticiones, isEmpty);
      expect(servicio.tokenRegistrado, isNull);
    });

    test('Si Firebase cambia el token, registra el nuevo', () async {
      final servicio = NotificacionesService(api: api, mensajeria: mensajeria);
      await servicio.activar();
      mensajeria.cambiarToken('fcm-token-nuevo-del-telefono-0002');
      await _esperar();

      expect(backend.peticiones.last.cuerpo['token'], 'fcm-token-nuevo-del-telefono-0002');
      expect(servicio.tokenRegistrado, 'fcm-token-nuevo-del-telefono-0002');
    });

    test('Si el backend falla no rompe la app y no da el token por registrado', () async {
      backend.status = 500;
      final servicio = NotificacionesService(api: api, mensajeria: mensajeria);
      await servicio.activar();

      expect(servicio.tokenRegistrado, isNull);
    });

    test('Al desactivar quita el token del backend y pide uno nuevo para la siguiente cuenta', () async {
      final servicio = NotificacionesService(api: api, mensajeria: mensajeria);
      await servicio.activar();
      await servicio.desactivar();

      expect(backend.peticiones.last.ruta, 'DELETE /notificaciones/dispositivo');
      expect(backend.peticiones.last.cuerpo, {'token': _token});
      expect(mensajeria.borrados, 1);
      expect(servicio.tokenRegistrado, isNull);

      // Después de desactivar, un cambio de token ya no se registra.
      mensajeria.cambiarToken('fcm-token-despues-de-salir-0003');
      await _esperar();
      expect(backend.peticiones.where((p) => p.ruta.startsWith('POST')), hasLength(1));
    });

    test('Si nunca se registró, desactivar no llama al backend', () async {
      await NotificacionesService(api: api, mensajeria: mensajeria).desactivar();
      expect(backend.peticiones, isEmpty);
    });
  });

  group('Con la sesión', () {
    AuthProvider crear() => AuthProvider(
      _AuthFalso(storage, api),
      notificaciones: NotificacionesService(api: api, mensajeria: mensajeria),
    );

    test('Al iniciar sesión registra el teléfono', () async {
      final auth = crear();
      expect(await auth.iniciarSesion('ana@correo.com', 'Secreta123'), isTrue);
      await _esperar();

      expect(backend.peticiones.single.ruta, 'POST /notificaciones/dispositivo');
      expect(backend.peticiones.single.conSesion, isTrue);
    });

    test('Al abrir la app con la sesión guardada registra el teléfono; sin sesión no', () async {
      await crear().restaurarSesion();
      await _esperar();
      expect(backend.peticiones, isEmpty);

      await storage.guardar('token-de-ana', const Usuario(email: 'ana@correo.com', nombre: 'Ana', rol: 'cliente'));
      await crear().restaurarSesion();
      await _esperar();
      expect(backend.peticiones.single.ruta, 'POST /notificaciones/dispositivo');
    });

    test('Al cerrar sesión quita el teléfono antes de borrar la sesión', () async {
      final auth = crear();
      await auth.iniciarSesion('ana@correo.com', 'Secreta123');
      await _esperar();
      await auth.cerrarSesion();

      final quitar = backend.peticiones.last;
      expect(quitar.ruta, 'DELETE /notificaciones/dispositivo');
      // El backend solo acepta la petición con la sesión de la cuenta.
      expect(quitar.conSesion, isTrue);
      expect(await storage.leerToken(), isNull);
      expect(auth.autenticado, isFalse);
    });
  });
}
