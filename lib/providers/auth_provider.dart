import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/usuario.dart';
import '../services/auth_service.dart';
import '../services/notificaciones_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service, {this._notificaciones, VoidCallback? alVencerSesion}) {
    // #272: si el backend rechaza la sesión y no se pudo renovar, la app queda sin sesión.
    _service.alVencerSesion(() {
      _usuario = null;
      notifyListeners();
      alVencerSesion?.call();
    });
  }

  final AuthService _service;
  // Notificaciones push del pedido (#55). Las pruebas que no las usan no la pasan.
  final NotificacionesService? _notificaciones;

  Usuario? _usuario;
  bool _cargando = false;
  String? _error;
  bool _sinVerificar = false;

  Usuario? get usuario => _usuario;
  bool get cargando => _cargando;
  String? get error => _error;
  // El último intento falló porque el correo no está confirmado.
  bool get sinVerificar => _sinVerificar;
  bool get autenticado => _usuario != null;

  Future<void> restaurarSesion() async {
    _usuario = await _service.sesionGuardada();
    notifyListeners();
    if (_usuario != null) unawaited(_notificaciones?.activar());
  }

  Future<bool> iniciarSesion(String email, String password, {bool recordar = true}) async {
    _cargando = true;
    _error = null;
    _sinVerificar = false;
    notifyListeners();
    try {
      _usuario = await _service.iniciarSesion(email, password, recordar: recordar);
      unawaited(_notificaciones?.activar());
      return true;
    } on AuthException catch (e) {
      _error = e.mensaje;
      _sinVerificar = e.sinVerificar;
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Tras "correo sin confirmar": manda otro enlace. Devuelve el texto para avisar al cliente.
  Future<String> reenviarVerificacion(String email, String password) async {
    try {
      final yaVerificado = await _service.reenviarVerificacion(email, password);
      if (yaVerificado) {
        _error = null;
        _sinVerificar = false;
        notifyListeners();
        return 'Tu correo ya está confirmado. Toca Iniciar sesión.';
      }
      return 'Te enviamos un nuevo enlace a ${email.trim()}. Revisa también tu carpeta de spam.';
    } on AuthException catch (e) {
      return e.mensaje;
    }
  }

  Future<List<String>> preguntasSecretas() => _service.preguntasSecretas();

  Future<bool> registrarse({
    required String nombre,
    required String email,
    required String password,
    required String tipoPregunta,
    String? preguntaPersonalizada,
    required String respuesta,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      await _service.registrarse(
        nombre: nombre,
        email: email,
        password: password,
        tipoPregunta: tipoPregunta,
        preguntaPersonalizada: preguntaPersonalizada,
        respuesta: respuesta,
      );
      return true;
    } on AuthException catch (e) {
      _error = e.mensaje;
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // El error es compartido por login y registro; se limpia al cambiar de pantalla.
  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // #273: el backend elimina la cuenta; si responde bien, se olvida la sesión del teléfono. Si falla
  // (por ejemplo, pedidos en curso), la sesión sigue abierta y el error llega a la pantalla.
  Future<void> eliminarCuenta(Future<void> Function() eliminarEnServidor) async {
    await eliminarEnServidor();
    await _service.olvidarSesion();
    _usuario = null;
    notifyListeners();
  }

  Future<void> cerrarSesion() async {
    // Primero se quita el teléfono de las notificaciones: el backend lo pide con la sesión activa.
    await _notificaciones?.desactivar();
    await _service.cerrarSesion();
    _usuario = null;
    notifyListeners();
  }
}
