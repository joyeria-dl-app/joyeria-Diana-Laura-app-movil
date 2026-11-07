import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'certificados.dart';
import 'session_storage.dart';

final String apiBaseUrl = AppConfig.instance.apiBaseUrl;

// Pide un token nuevo del backend sin la contraseña; null si no se pudo (#272).
typedef RenovarSesion = Future<String?> Function();

class ApiClient {
  ApiClient({Dio? dio, SessionStorage? storage})
    : _storage = storage,
      dio =
          dio ??
          _conPinning(
            Dio(
              BaseOptions(
                baseUrl: apiBaseUrl,
                // Render apaga el servicio sin uso; la primera petición puede tardar en despertarlo.
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                headers: {'Content-Type': 'application/json'},
              ),
            ),
          ) {
    if (storage != null) {
      this.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await storage.leerToken();
            if (token != null) options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          },
          onError: _alFallar,
        ),
      );
    }
  }

  final Dio dio;
  final SessionStorage? _storage;

  // Los asignan AuthService y AuthProvider: renovar el token y avisar que la sesión terminó.
  RenovarSesion? renovarSesion;
  VoidCallback? alVencerSesion;

  // Una sola renovación a la vez: si varias peticiones reciben 401 juntas, esperan la misma.
  Future<String?>? _renovando;

  // Token de la sesión, para las páginas del backend que se abren en el navegador (recibo).
  Future<String?> token() async => _storage?.leerToken();

  // #272: ante un 401 se pide un token nuevo con Firebase y se repite la petición una vez. Si no se
  // puede renovar, la sesión se borra y la app lleva a iniciar sesión.
  Future<void> _alFallar(DioException error, ErrorInterceptorHandler handler) async {
    final peticion = error.requestOptions;
    final storage = _storage;
    final renovar = renovarSesion;
    final esLogin = peticion.path.startsWith('/auth/login');
    if (error.response?.statusCode != 401 || storage == null || esLogin || peticion.extra['reintento'] == true) {
      return handler.next(error);
    }
    // Sin sesión guardada el 401 es normal (pantallas que invitan a iniciar sesión).
    if (await storage.leerToken() == null) return handler.next(error);

    String? nuevo;
    if (renovar != null) {
      _renovando ??= renovar().whenComplete(() => _renovando = null);
      try {
        nuevo = await _renovando;
      } on Object {
        nuevo = null;
      }
    }
    if (nuevo == null) {
      await storage.borrar();
      alVencerSesion?.call();
      return handler.next(error);
    }

    peticion.headers['Authorization'] = 'Bearer $nuevo';
    peticion.extra['reintento'] = true;
    try {
      handler.resolve(await dio.fetch<dynamic>(peticion));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  // Certificate Pinning (#272): en el teléfono el cliente HTTP solo confía en las autoridades
  // fijadas en certificados.dart. En web no hay control de TLS desde la app.
  static Dio _conPinning(Dio dio) {
    if (!kIsWeb && apiBaseUrl.startsWith('https://')) {
      dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: clienteConPinning);
    }
    return dio;
  }
}
