import 'package:flutter/foundation.dart';

import '../models/usuario.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service);

  final AuthService _service;

  Usuario? _usuario;
  bool _cargando = false;
  String? _error;

  Usuario? get usuario => _usuario;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get autenticado => _usuario != null;

  Future<void> restaurarSesion() async {
    _usuario = await _service.sesionGuardada();
    notifyListeners();
  }

  Future<bool> iniciarSesion(String email, String password) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _usuario = await _service.iniciarSesion(email, password);
      return true;
    } on AuthException catch (e) {
      _error = e.mensaje;
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> cerrarSesion() async {
    await _service.cerrarSesion();
    _usuario = null;
    notifyListeners();
  }
}
