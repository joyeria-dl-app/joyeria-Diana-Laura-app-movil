import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

// Lo que la app usa de Firebase Cloud Messaging. Las pruebas lo reemplazan para no depender de
// Firebase ni del teléfono.
abstract class MensajeriaPush {
  // Pide el permiso de notificaciones (en Android 13 o más aparece el aviso del sistema).
  Future<bool> pedirPermiso();
  Future<String?> token();
  // Firebase cambia el token de vez en cuando; el nuevo se vuelve a registrar.
  Stream<String> get tokenNuevo;
  Future<void> borrarToken();
}

// Usa el token de registro de FCM, que es el que el backend manda con Firebase Admin
// (sendEachForMulticast). firebase_messaging 17 lo marca como obsoleto en favor del registro por
// Firebase Installation ID, pero sigue funcionando y el backend aún no envía de esa otra forma.
class FirebaseMensajeria implements MensajeriaPush {
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  @override
  Future<bool> pedirPermiso() async {
    final ajustes = await _fcm.requestPermission();
    return ajustes.authorizationStatus == AuthorizationStatus.authorized || ajustes.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  // ignore: deprecated_member_use
  Future<String?> token() => _fcm.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenNuevo => _fcm.onTokenRefresh;

  @override
  // ignore: deprecated_member_use
  Future<void> borrarToken() => _fcm.deleteToken();
}

// Notificaciones push del estado del pedido (HU-15, #55). Con sesión, el teléfono se registra en el
// backend para recibir los avisos de esa cuenta; al cerrar sesión se quita. Nada de esto debe
// impedir usar la app: si no hay permiso, conexión o Firebase, la sesión sigue igual.
class NotificacionesService {
  NotificacionesService({required this._api, required this._mensajeria});

  final ApiClient _api;
  final MensajeriaPush _mensajeria;
  String? _registrado;
  StreamSubscription<String>? _cambios;

  // Token que quedó registrado en el backend (null si no se pudo o no hay permiso).
  String? get tokenRegistrado => _registrado;

  // Al iniciar sesión o al abrir la app con la sesión guardada.
  Future<void> activar() async {
    try {
      if (!await _mensajeria.pedirPermiso()) return;
      final token = await _mensajeria.token();
      if (token == null) return;
      await _registrar(token);
      _cambios ??= _mensajeria.tokenNuevo.listen((nuevo) => _registrar(nuevo).catchError((Object e) => debugPrint('Push: $e')));
    } on Object catch (e) {
      debugPrint('No se pudo activar las notificaciones: $e');
    }
  }

  // Antes de borrar la sesión, para que el backend acepte la petición con el token de la cuenta.
  Future<void> desactivar() async {
    await _cambios?.cancel();
    _cambios = null;
    final token = _registrado;
    _registrado = null;
    if (token == null) return;
    try {
      await _api.dio.delete('/notificaciones/dispositivo', data: {'token': token}).timeout(const Duration(seconds: 5));
      // Un token nuevo para la siguiente cuenta que use este teléfono.
      await _mensajeria.borrarToken();
    } on Object catch (e) {
      debugPrint('No se pudo quitar el teléfono de las notificaciones: $e');
    }
  }

  Future<void> _registrar(String token) async {
    await _api.dio.post('/notificaciones/dispositivo', data: {'token': token, 'plataforma': 'android'});
    _registrado = token;
  }
}
