// TIPO: aceptación simulada (flujo)
// ALCANCE: HU-16 · criterio: el cliente ve las mismas zonas de entrega que administra el negocio en el sitio web
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/zonas_flujo_test.dart
// DATOS: backend simulado en memoria a nivel HTTP (sin red); zonas y datos de la tienda con la forma real de producción

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/models/usuario.dart';
import 'package:joyeria_diana_laura/screens/zonas_entrega_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/auth_service.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/perfil_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/services/zonas_service.dart';

// HU-16 · Criterio de aceptación: el cliente abre Zonas de entrega desde Mi perfil y ve las zonas
// activas en el orden que la tienda les da en el sitio web, con la zona donde está la tienda
// marcada, la dirección y el horario para recoger y el botón para preguntar por su zona. Corre la
// app completa con los servicios reales; lo que se simula es el backend, que responde por HTTP
// desde memoria con los mismos endpoints públicos que usa el sitio web.

const _base = 'https://joyeria.example/api';
const _token = 'token-de-ana';

class _Servidor implements HttpClientAdapter {
  // Como las administra el negocio: una zona inactiva y el orden que les dio en su panel.
  List<Map<String, Object?>> zonas = [
    {'id': 3, 'nombre': 'Jaltocan', 'activo': true, 'orden': 3},
    {'id': 1, 'nombre': 'Huejutla', 'activo': true, 'orden': 1},
    {'id': 6, 'nombre': 'Orizatlán', 'activo': false, 'orden': 2},
    {'id': 2, 'nombre': 'San Felipe', 'activo': true, 'orden': 2},
  ];
  Map<String, Object?> tienda = {
    'direccion': 'Calle Hidalgo 12, Centro, Huejutla de Reyes, Hgo.',
    'horario': 'Lunes a sábado de 10:00 a 19:00',
    'whatsapp': '+52 771 332 1421',
  };
  bool sinZonas = false;
  bool sinTienda = false;
  final List<String> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final ruta = '${options.method} ${options.path}';
    peticiones.add(ruta);
    switch (ruta) {
      case 'GET /zonas-entrega':
        return sinZonas ? _json(500, {'success': false}) : _json(200, {'success': true, 'data': zonas});
      case 'GET /content/info-empresa':
        return sinTienda ? _json(500, {'success': false}) : _json(200, {'success': true, 'data': tienda});
      case 'GET /auth/profile':
        return _json(200, {
          'success': true,
          'data': {'nombre': 'Ana Martínez', 'email': 'ana.martinez@correo.com', 'fecha_creacion': '2026-10-02T15:20:00.000Z'},
        });
      case 'GET /carrito/pedidos/mis':
      case 'GET /apartados/mis-apartados':
      case 'GET /favoritos':
        return _json(200, {'success': true, 'data': <Object>[]});
      case 'GET /carrito':
        return _json(200, {
          'success': true,
          'data': {'items': <Object>[], 'total': 0, 'count': 0},
        });
      case 'GET /carrito/count':
        return _json(200, {
          'success': true,
          'data': {'count': 0},
        });
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

class _App {
  _App(this.servidor);
  final _Servidor servidor;
  final List<Uri> enlaces = [];
}

Future<_App> _abrir(WidgetTester tester, {_Servidor? servidor}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);

  final app = _App(servidor ?? _Servidor());
  final storage = MemorySessionStorage();
  await storage.guardar(_token, const Usuario(email: 'ana.martinez@correo.com', nombre: 'Ana Martínez', rol: 'cliente'));
  final api = ApiClient(
    dio: Dio(BaseOptions(baseUrl: _base))..httpClientAdapter = app.servidor,
    storage: storage,
  );
  final pedidos = PedidoService(api: api);
  final favoritos = FavoritoService(api: api);
  abrirEnlaceZonas = (uri) async {
    app.enlaces.add(uri);
    return true;
  };

  await tester.pumpWidget(
    JoyeriaApp(
      storage: storage,
      authService: AuthService(api: api, storage: storage),
      carritoService: CarritoService(api: api),
      favoritoService: favoritos,
      pedidoService: pedidos,
      perfilService: PerfilService(api: api, pedidos: pedidos, favoritos: favoritos),
      zonasService: ZonasService(api: api),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

Future<void> _irAZonas(WidgetTester tester) async {
  await _tocar(tester, find.byKey(const Key('nav_perfil')));
  await _tocar(tester, find.text('Zonas de entrega'));
  expect(find.byType(ZonasEntregaScreen), findsOneWidget);
}

void main() {
  testWidgets('Desde Mi perfil abre las zonas activas en el orden que les da la tienda', (tester) async {
    final app = await _abrir(tester);
    await _irAZonas(tester);

    expect(app.servidor.peticiones, containsAll(['GET /zonas-entrega', 'GET /content/info-empresa']));
    final arriba = [
      for (final zona in ['Huejutla', 'San Felipe', 'Jaltocan']) tester.getTopLeft(find.text(zona)).dy,
    ];
    expect(arriba, orderedEquals([...arriba]..sort()));
    // La zona que el negocio desactivó no se muestra.
    expect(find.text('Orizatlán'), findsNothing);
    // Huejutla aparece en la dirección de la tienda.
    expect(find.text('Aquí está la tienda'), findsOneWidget);
  });

  testWidgets('Muestra la tienda para recoger con su dirección y horario', (tester) async {
    final app = await _abrir(tester);
    await _irAZonas(tester);
    await tester.scrollUntilVisible(find.text('Cómo llegar'), 200);
    await tester.pumpAndSettle();

    expect(find.text('También puedes recoger en tienda'), findsOneWidget);
    expect(find.text(app.servidor.tienda['direccion']! as String), findsOneWidget);
    expect(find.text(app.servidor.tienda['horario']! as String), findsOneWidget);
  });

  testWidgets('Preguntar por mi zona abre WhatsApp de la tienda con el mensaje del sitio web', (tester) async {
    final app = await _abrir(tester);
    await _irAZonas(tester);
    await _tocar(tester, find.byKey(const Key('zonas_preguntar')));

    expect(app.enlaces.single.toString(), 'https://wa.me/527713321421?text=Hola%2C+%C2%BFhacen+entregas+en+mi+zona%3F');
  });

  testWidgets('Si el negocio cambia sus zonas, la app muestra las nuevas al volver a abrir', (tester) async {
    final servidor = _Servidor();
    await _abrir(tester, servidor: servidor);
    await _irAZonas(tester);
    expect(find.text('Jaltocan'), findsOneWidget);

    servidor.zonas = [
      {'id': 3, 'nombre': 'Jaltocan', 'activo': false, 'orden': 3},
      {'id': 1, 'nombre': 'Huejutla', 'activo': true, 'orden': 1},
      {'id': 7, 'nombre': 'Tehuetlán', 'activo': true, 'orden': 4},
    ];
    Navigator.of(tester.element(find.byType(ZonasEntregaScreen))).pop();
    await tester.pumpAndSettle();
    await _tocar(tester, find.text('Zonas de entrega'));

    expect(find.text('Tehuetlán'), findsOneWidget);
    expect(find.text('Jaltocan'), findsNothing);
  });

  testWidgets('Si solo fallan las zonas, igual muestra la tienda para recoger', (tester) async {
    await _abrir(tester, servidor: _Servidor()..sinZonas = true);
    await _irAZonas(tester);

    expect(find.text('No se pudieron cargar las zonas'), findsOneWidget);
    expect(find.byKey(const Key('zonas_preguntar')), findsOneWidget);
  });

  testWidgets('Sin conexión deja reintentar y entonces muestra las zonas', (tester) async {
    final servidor = _Servidor()
      ..sinZonas = true
      ..sinTienda = true;
    await _abrir(tester, servidor: servidor);
    await _irAZonas(tester);
    expect(find.text('Sin conexión'), findsOneWidget);

    servidor
      ..sinZonas = false
      ..sinTienda = false;
    await _tocar(tester, find.text('Reintentar'));
    expect(find.text('Huejutla'), findsOneWidget);
  });
}
