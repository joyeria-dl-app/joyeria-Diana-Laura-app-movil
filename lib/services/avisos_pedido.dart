import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Aviso del cambio de estado de un pedido, como lo manda el backend (HU-15): título, texto y los
// datos {tipo: 'pedido', pedido_id, estado}.
class AvisoPush {
  const AvisoPush({required this.titulo, required this.cuerpo, required this.datos});
  final String titulo;
  final String cuerpo;
  final Map<String, dynamic> datos;
}

// Número del pedido que trae el aviso, o null si el aviso no es de un pedido.
int? pedidoDelAviso(Map<String, dynamic> datos) => datos['tipo'] == 'pedido' ? int.tryParse('${datos['pedido_id']}') : null;

// De dónde llegan los avisos y cómo se muestran. Las pruebas lo reemplazan para no depender de
// Firebase ni del teléfono.
abstract class FuenteAvisos {
  // Prepara el canal Pedidos; onTocar recibe los datos del aviso que se tocó con la app abierta.
  Future<void> preparar(void Function(Map<String, dynamic> datos) onTocar);
  // Avisos que llegan con la app abierta (Android no los muestra solo).
  Stream<AvisoPush> get enPrimerPlano;
  // Avisos tocados con la app en segundo plano.
  Stream<Map<String, dynamic>> get tocadosEnFondo;
  // Aviso que abrió la app cuando estaba cerrada.
  Future<Map<String, dynamic>?> avisoInicial();
  Future<void> mostrar(AvisoPush aviso);
}

class FirebaseFuenteAvisos implements FuenteAvisos {
  final _locales = FlutterLocalNotificationsPlugin();

  // Mismo id que manda el backend (android.notification.channelId) y que usa el manifiesto.
  static const canal = AndroidNotificationChannel(
    'pedidos',
    'Pedidos',
    description: 'Avisos cuando cambia el estado de tus pedidos',
    importance: Importance.high,
  );

  @override
  Future<void> preparar(void Function(Map<String, dynamic> datos) onTocar) async {
    await _locales.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notificacion')),
      onDidReceiveNotificationResponse: (respuesta) {
        final payload = respuesta.payload;
        if (payload != null) onTocar(jsonDecode(payload) as Map<String, dynamic>);
      },
    );
    await _locales.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(canal);
  }

  @override
  Stream<AvisoPush> get enPrimerPlano => FirebaseMessaging.onMessage.map(
    (m) => AvisoPush(titulo: m.notification?.title ?? 'Joyería Diana Laura', cuerpo: m.notification?.body ?? '', datos: m.data),
  );

  @override
  Stream<Map<String, dynamic>> get tocadosEnFondo => FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  @override
  Future<Map<String, dynamic>?> avisoInicial() async => (await FirebaseMessaging.instance.getInitialMessage())?.data;

  @override
  Future<void> mostrar(AvisoPush aviso) => _locales.show(
    // Un id distinto por aviso: si llegan dos avisos del mismo pedido, se ven los dos.
    id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
    title: aviso.titulo,
    body: aviso.cuerpo,
    payload: jsonEncode(aviso.datos),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        canal.id,
        canal.name,
        channelDescription: canal.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notificacion',
      ),
    ),
  );
}

// Avisos del pedido (HU-15, #56): con la app abierta muestra el aviso en el canal Pedidos, y al
// tocar un aviso (con la app abierta, en segundo plano o cerrada) abre el seguimiento del pedido.
class AvisosPedido {
  AvisosPedido({required this._fuente, required this._abrirPedido});

  final FuenteAvisos _fuente;
  final void Function(int pedidoId) _abrirPedido;
  final List<StreamSubscription<Object>> _escuchas = [];

  Future<void> iniciar() async {
    try {
      await _fuente.preparar(_tocado);
      _escuchas
        ..add(_fuente.enPrimerPlano.listen((aviso) => _fuente.mostrar(aviso).catchError((Object e) => debugPrint('Aviso: $e'))))
        ..add(_fuente.tocadosEnFondo.listen(_tocado));
      final inicial = await _fuente.avisoInicial();
      if (inicial != null) _tocado(inicial);
    } on Object catch (e) {
      debugPrint('No se pudieron preparar los avisos del pedido: $e');
    }
  }

  void _tocado(Map<String, dynamic> datos) {
    final pedido = pedidoDelAviso(datos);
    if (pedido != null) _abrirPedido(pedido);
  }

  Future<void> detener() async {
    for (final e in _escuchas) {
      await e.cancel();
    }
    _escuchas.clear();
  }
}
