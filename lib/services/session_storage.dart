import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/usuario.dart';

abstract class SessionStorage {
  Future<void> guardar(String token, Usuario usuario);
  Future<String?> leerToken();
  Future<Usuario?> leerUsuario();
  Future<void> borrar();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _claveToken = 'auth_token';
  static const _claveUsuario = 'auth_usuario';

  @override
  Future<void> guardar(String token, Usuario usuario) async {
    await _storage.write(key: _claveToken, value: token);
    await _storage.write(key: _claveUsuario, value: jsonEncode(usuario.toJson()));
  }

  @override
  Future<String?> leerToken() => _storage.read(key: _claveToken);

  @override
  Future<Usuario?> leerUsuario() async {
    final json = await _storage.read(key: _claveUsuario);
    return json == null ? null : Usuario.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  @override
  Future<void> borrar() async {
    await _storage.delete(key: _claveToken);
    await _storage.delete(key: _claveUsuario);
  }
}

class MemorySessionStorage implements SessionStorage {
  String? _token;
  Usuario? _usuario;

  @override
  Future<void> guardar(String token, Usuario usuario) async {
    _token = token;
    _usuario = usuario;
  }

  @override
  Future<String?> leerToken() async => _token;

  @override
  Future<Usuario?> leerUsuario() async => _usuario;

  @override
  Future<void> borrar() async {
    _token = null;
    _usuario = null;
  }
}
