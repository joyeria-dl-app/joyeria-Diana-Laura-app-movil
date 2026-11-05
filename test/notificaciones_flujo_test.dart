// TIPO: aceptación simulada (flujo)
// ALCANCE: HU-15 · criterio: al cambiar el estado de un pedido, el cliente recibe el aviso y al tocarlo ve su pedido
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/notificaciones_flujo_test.dart
// DATOS: backend simulado en memoria a nivel HTTP y Firebase Cloud Messaging simulado (sin red); cuenta y pedido de ejemplo

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/models/usuario.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/auth_service.dart';
import 'package:joyeria_diana_laura/services/avisos_pedido.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/services/notificaciones_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

// HU-15 · Criterio de aceptación: al cambiar el estado de un pedido, el celular del cliente recibe la
// notificación. Corre la app completa con sus servicios reales; el backend responde por HTTP desde
// memoria (guarda los teléfonos registrados) y la prueba hace de Firebase Cloud Messaging: entrega
// el aviso con la app abierta o lo "toca" como lo haría el cliente.

const _token = 'token-de-ana';
const _tokenTelefono = 'fcm-token-del-telefono-de-ana-0001';

class _Servidor implements HttpClientAdapter {
  final Set<String> telefonos = {};
  final List<String> peticiones = [];

  static final _pedido = {
    'id': 51,
    'folio': 'DL-1791300000051',
    'estado': 'confirmado',
    'total': '1160.64',
    'costo_envio': '0',
    'tipo_entrega': 'tienda',
    'metodo_pago_nombre': 'Efectivo en Tienda',
    'metodo_pago_codigo': 'efectivo',
    'estado_pago': 'pendiente',
    'fecha_creacion': '2026-10-15T21:05:00.000Z',
    'items': [
      {'producto_nombre': 'Anillo lila halo', 'producto_imagen': null, 'cantidad': 1, 'precio_unitario': '1160.64'},
    ],
    'historial': [
      {'estado': 'pendiente', 'fecha': '2026-10-15T21:05:00.000Z', 'comentario': null},
      {'estado': 'confirmado', 'fecha': '2026-10-16T15:00:00.000Z', 'comentario': null},
    ],
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final ruta = '${options.method} ${options.path}';
    peticiones.add(ruta);
    if (options.headers['Authorization'] != 'Bearer $_token') return _json(401, {'success': false, 'message': 'Token inválido'});
    final cuerpo = options.data is Map ? Map<String, dynamic>.from(options.data as Map) : const <String, dynamic>{};
    switch (ruta) {
      case 'POST /notificaciones/dispositivo':
        telefonos.add(cuerpo['token'] as String);
        return _json(200, {'success': true});
      case 'DELETE /notificaciones/dispositivo':
        telefonos.remove(cuerpo['token']);
        return _json(200, {'success': true, 'quitado': true});
      case 'GET /carrito/pedidos/mis':
        return _json(200, {
          'success': true,
          'data': [_pedido],
        });
      case 'GET /carrito/count':
        return _json(200, {
          'success': true,
          'data': {'count': 0},
        });
      case 'GET /carrito':
        return _json(200, {
          'success': true,
          'data': {'items': <Object>[], 'total': 0, 'count': 0},
        });
      case 'GET /favoritos':
        return _json(200, {'success': true, 'data': <Object>[]});
      // Mi perfil (desde #244 ahí está Cerrar sesión).
      case 'GET /auth/profile':
        return _json(200, {
          'success': true,
          'data': {'nombre': 'Ana Martínez', 'email': 'ana.martinez@correo.com'},
        });
      case 'GET /apartados/mis-apartados':
        return _json(200, {'success': true, 'data': <Object>[]});
      case 'POST /auth/logout':
        return _json(200, {'success': true});
    }
    return _json(404, {'success': false, 'message': 'Ruta no simulada: $ruta'});
  }

  ResponseBody _json(int status, Map<String, dynamic> cuerpo) => ResponseBody.fromString(
    jsonEncode(cuerpo),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

// Firebase Cloud Messaging del teléfono: permiso, token y avisos.
class _Fcm implements MensajeriaPush, FuenteAvisos {
  bool permiso = true;
  final primerPlano = StreamController<AvisoPush>.broadcast();
  final fondo = StreamController<Map<String, dynamic>>.broadcast();
  void Function(Map<String, dynamic>)? _tocarAvisoMostrado;
  final List<AvisoPush> mostrados = [];

  @override
  Future<bool> pedirPermiso() async => permiso;
  @override
  Future<String?> token() async => _tokenTelefono;
  @override
  Stream<String> get tokenNuevo => const Stream.empty();
  @override
  Future<void> borrarToken() async {}

  @override
  Future<void> preparar(void Function(Map<String, dynamic> datos) onTocar) async => _tocarAvisoMostrado = onTocar;
  @override
  Stream<AvisoPush> get enPrimerPlano => primerPlano.stream;
  @override
  Stream<Map<String, dynamic>> get tocadosEnFondo => fondo.stream;
  @override
  Future<Map<String, dynamic>?> avisoInicial() async => null;
  @override
  Future<void> mostrar(AvisoPush aviso) async => mostrados.add(aviso);

  void tocarMostrado(Map<String, dynamic> datos) => _tocarAvisoMostrado!(datos);
}

AvisoPush _aviso(int pedidoId) => AvisoPush(
  titulo: 'Pedido confirmado',
  cuerpo: 'Confirmamos tu pedido y ya lo estamos procesando. Folio DL-1791300000051.',
  datos: {'tipo': 'pedido', 'pedido_id': '$pedidoId', 'estado': 'confirmado'},
);

class _App {
  _App(this.servidor, this.fcm, this.storage);
  final _Servidor servidor;
  final _Fcm fcm;
  final MemorySessionStorage storage;
}

Future<_App> _abrir(WidgetTester tester, {bool permiso = true}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);

  final servidor = _Servidor();
  final fcm = _Fcm()..permiso = permiso;
  final storage = MemorySessionStorage();
  await storage.guardar(_token, const Usuario(email: 'ana@correo.com', nombre: 'Ana Martínez', rol: 'cliente'));
  final api = ApiClient(
    dio: Dio(BaseOptions(baseUrl: 'https://joyeria.example/api'))..httpClientAdapter = servidor,
    storage: storage,
  );

  await tester.pumpWidget(
    JoyeriaApp(
      storage: storage,
      authService: AuthService(api: api, storage: storage),
      carritoService: CarritoService(api: api),
      favoritoService: FavoritoService(api: api),
      pedidoService: PedidoService(api: api),
      mensajeria: fcm,
      apiClient: api,
    ),
  );
  // Como en main(): los avisos se preparan después del primer cuadro.
  final avisos = AvisosPedido(fuente: fcm, abrirPedido: abrirPedidoDesdeAviso);
  await avisos.iniciar();
  addTearDown(avisos.detener);
  await tester.pumpAndSettle();
  return _App(servidor, fcm, storage);
}

void main() {
  testWidgets('Al abrir la app con sesión, el teléfono queda registrado para recibir avisos', (tester) async {
    final app = await _abrir(tester);
    expect(find.textContaining('Ana Martínez'), findsOneWidget);
    expect(app.servidor.telefonos, {_tokenTelefono});
  });

  testWidgets('Sin permiso de notificaciones no se registra y la app funciona igual', (tester) async {
    final app = await _abrir(tester, permiso: false);
    expect(app.servidor.telefonos, isEmpty);
    expect(find.byKey(const Key('inicio_saludo')), findsOneWidget);
  });

  testWidgets('El aviso que llega con la app abierta se muestra', (tester) async {
    final app = await _abrir(tester);
    app.fcm.primerPlano.add(_aviso(51));
    await tester.pumpAndSettle();

    expect(app.fcm.mostrados.single.titulo, 'Pedido confirmado');
    // Mostrarlo no cambia de pantalla: solo se abre si el cliente lo toca.
    expect(find.byType(SeguimientoScreen), findsNothing);
  });

  testWidgets('Al tocar el aviso mostrado se abre el seguimiento del pedido', (tester) async {
    final app = await _abrir(tester);
    app.fcm.primerPlano.add(_aviso(51));
    await tester.pumpAndSettle();
    app.fcm.tocarMostrado(app.fcm.mostrados.single.datos);
    await tester.pumpAndSettle();

    expect(find.byType(SeguimientoScreen), findsOneWidget);
    expect(find.textContaining('DL-1791300000051'), findsWidgets);
    expect(app.servidor.peticiones, contains('GET /carrito/pedidos/mis'));
  });

  testWidgets('Al tocar el aviso con la app en segundo plano también se abre el pedido', (tester) async {
    final app = await _abrir(tester);
    app.fcm.fondo.add(_aviso(51).datos);
    await tester.pumpAndSettle();

    expect(find.byType(SeguimientoScreen), findsOneWidget);
  });

  testWidgets('Un aviso de un pedido que no es de la cuenta no muestra nada ajeno', (tester) async {
    final app = await _abrir(tester);
    app.fcm.fondo.add(_aviso(99).datos);
    await tester.pumpAndSettle();

    expect(find.text('No encontramos ese pedido'), findsOneWidget);
    expect(find.byType(SeguimientoScreen), findsNothing);
  });

  testWidgets('Al cerrar sesión se quita el teléfono antes de borrar la sesión', (tester) async {
    final app = await _abrir(tester);
    // Desde #244 Cerrar sesión está en Mi perfil.
    await tester.tap(find.byKey(const Key('nav_perfil')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    // Desde #219 se confirma antes de cerrar la sesión.
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
    // Cerrar sesión espera la respuesta del backend (con límite de 5 s); se deja pasar tiempo real.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    final quitar = app.servidor.peticiones.indexOf('DELETE /notificaciones/dispositivo');
    expect(quitar, isNot(-1));
    expect(app.servidor.telefonos, isEmpty);
    expect(await app.storage.leerToken(), isNull);
    expect(find.text('Iniciar sesión'), findsWidgets);
  });
}
