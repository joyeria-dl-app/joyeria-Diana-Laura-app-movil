import 'package:dio/dio.dart';

import '../models/usuario.dart';
import 'api_client.dart';
import 'session_storage.dart';

// Se define al compilar: flutter run --dart-define-from-file=env.json
const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');

// Valor que el backend usa para registrar un intento fallido sin crear sesión.
const String _intentoFallido = 'wrong_password_to_trigger_failure';

class AuthException implements Exception {
  const AuthException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class AuthService {
  AuthService({required this._api, required this._storage, Dio? firebaseDio, String? apiKey})
      : _firebase = firebaseDio ?? Dio(BaseOptions(baseUrl: 'https://identitytoolkit.googleapis.com/v1')),
        _apiKey = apiKey ?? firebaseApiKey;

  final ApiClient _api;
  final SessionStorage _storage;
  final Dio _firebase;
  final String _apiKey;

  Future<Usuario> iniciarSesion(String email, String password) async {
    final correo = email.trim();
    final idToken = await _validarConFirebase(correo, password);

    final Response<dynamic> respuesta;
    try {
      respuesta = await _api.dio.post('/auth/login/movil', data: {'idToken': idToken});
    } on DioException catch (e) {
      throw AuthException(_mensajeBackend(e));
    }

    final data = respuesta.data as Map<String, dynamic>;
    if (data['mfaRequired'] == true || data['requiresMFA'] == true) {
      throw const AuthException('Tu cuenta usa verificación en dos pasos. Por ahora inicia sesión desde el sitio web.');
    }
    if (data['requiresWorkerVerification'] == true) {
      throw const AuthException('Esta app es para clientes. El personal debe entrar desde el sitio web.');
    }

    final datos = data['data'] as Map<String, dynamic>?;
    final token = datos?['token'] as String?;
    if (data['success'] != true || token == null) {
      throw AuthException(data['message'] as String? ?? 'No se pudo iniciar sesión.');
    }

    final usuario = Usuario.fromJson(datos!['user'] as Map<String, dynamic>);
    await _storage.guardar(token, usuario);
    return usuario;
  }

  Future<Usuario?> sesionGuardada() async {
    final token = await _storage.leerToken();
    return token == null ? null : _storage.leerUsuario();
  }

  Future<void> cerrarSesion() => _storage.borrar();

  Future<String> _validarConFirebase(String email, String password) async {
    if (_apiKey.isEmpty) {
      throw const AuthException('Falta la configuración de Firebase (env.json).');
    }
    try {
      final respuesta = await _firebase.post(
        '/accounts:signInWithPassword',
        queryParameters: {'key': _apiKey},
        data: {'email': email, 'password': password, 'returnSecureToken': true},
      );
      return (respuesta.data as Map<String, dynamic>)['idToken'] as String;
    } on DioException catch (e) {
      final codigo = _codigoFirebase(e);
      if (codigo == 'INVALID_LOGIN_CREDENTIALS' || codigo == 'EMAIL_NOT_FOUND' || codigo == 'INVALID_PASSWORD') {
        throw AuthException(await _registrarIntentoFallido(email));
      }
      throw AuthException(switch (codigo) {
        'INVALID_EMAIL' => 'El formato del correo no es válido.',
        'USER_DISABLED' => 'Esta cuenta está deshabilitada.',
        'TOO_MANY_ATTEMPTS_TRY_LATER' => 'Demasiados intentos. Espera unos minutos e intenta de nuevo.',
        _ => 'Revisa tu conexión a internet e intenta de nuevo.',
      });
    }
  }

  Future<String> _registrarIntentoFallido(String email) async {
    try {
      await _api.dio.post('/auth/login', data: {'email': email, 'password': _intentoFallido});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        if (e.response?.statusCode == 423) return data['message'] as String? ?? 'Tu cuenta está bloqueada.';
        final restantes = data['remainingAttempts'];
        if (restantes is int) return 'Correo o contraseña incorrectos. Te quedan $restantes intentos.';
      }
    }
    return 'Correo o contraseña incorrectos.';
  }

  String? _codigoFirebase(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      // Algunos códigos traen detalle: "TOO_MANY_ATTEMPTS_TRY_LATER : ..."
      return (data['error']['message'] as String?)?.split(' ').first;
    }
    return null;
  }

  String _mensajeBackend(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'No se pudo conectar con el servidor. Intenta de nuevo.';
  }
}
