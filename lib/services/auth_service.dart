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

  Future<Usuario> iniciarSesion(String email, String password, {bool recordar = true}) async {
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
    await _storage.guardar(token, usuario, recordar: recordar);
    return usuario;
  }

  // Se llama al abrir la app: una sesión sin "Recordarme" no se conserva.
  Future<Usuario?> sesionGuardada() async {
    final token = await _storage.leerToken();
    if (token == null) return null;
    if (!await _storage.leerRecordar()) {
      await _storage.borrar();
      return null;
    }
    return _storage.leerUsuario();
  }

  Future<void> cerrarSesion() => _storage.borrar();

  Future<List<String>> preguntasSecretas() async {
    try {
      final respuesta = await _api.dio.get('/security/secure-questions');
      return List<String>.from((respuesta.data as Map<String, dynamic>)['data']['questions'] as List);
    } on DioException catch (e) {
      throw AuthException(_mensajeBackend(e));
    }
  }

  // Mismo flujo que el registro del sitio web: cuenta en Firebase con su nombre,
  // correo de verificación, alta en la base de datos y pregunta secreta.
  // `tipoPregunta` es el índice de la lista o 'custom'. La sesión no se abre:
  // primero hay que confirmar el correo.
  Future<void> registrarse({
    required String nombre,
    required String email,
    required String password,
    required String tipoPregunta,
    String? preguntaPersonalizada,
    required String respuesta,
  }) async {
    _revisarConfiguracion();
    final correo = email.trim();

    final String idToken;
    try {
      final r = await _firebase.post(
        '/accounts:signUp',
        queryParameters: {'key': _apiKey},
        data: {'email': correo, 'password': password, 'returnSecureToken': true},
      );
      idToken = (r.data as Map<String, dynamic>)['idToken'] as String;
    } on DioException catch (e) {
      throw AuthException(switch (_codigoFirebase(e)) {
        'EMAIL_EXISTS' => 'Este correo ya tiene una cuenta. Inicia sesión o recupera tu contraseña.',
        'INVALID_EMAIL' => 'El formato del correo no es válido.',
        'WEAK_PASSWORD' => 'La contraseña es demasiado débil.',
        'TOO_MANY_ATTEMPTS_TRY_LATER' => 'Demasiados intentos. Espera unos minutos e intenta de nuevo.',
        _ => 'Revisa tu conexión a internet e intenta de nuevo.',
      });
    }

    try {
      await _firebase.post('/accounts:update',
          queryParameters: {'key': _apiKey}, data: {'idToken': idToken, 'displayName': nombre.trim()});
      await _firebase.post('/accounts:sendOobCode',
          queryParameters: {'key': _apiKey}, data: {'requestType': 'VERIFY_EMAIL', 'idToken': idToken});
    } on DioException {
      throw const AuthException('Tu cuenta se creó, pero no pudimos enviar el correo de verificación. Intenta iniciar sesión más tarde.');
    }

    try {
      await _api.dio.post('/auth/sync-user/movil', data: {'idToken': idToken, 'nombre': nombre.trim()});
      await _api.dio.post('/security/set-security-question', data: {
        'email': correo,
        'questionType': tipoPregunta,
        'customQuestion': preguntaPersonalizada ?? '',
        'answer': respuesta.trim(),
        'idToken': idToken,
      });
    } on DioException catch (e) {
      throw AuthException(_mensajeBackend(e));
    }
  }

  void _revisarConfiguracion() {
    if (_apiKey.isEmpty) {
      throw const AuthException('Falta la configuración de Firebase (env.json).');
    }
  }

  Future<String> _validarConFirebase(String email, String password) async {
    _revisarConfiguracion();
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
        if (restantes is int) {
          final intentos = restantes == 1 ? 'Te queda 1 intento' : 'Te quedan $restantes intentos';
          return 'Correo o contraseña incorrectos. $intentos.';
        }
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
