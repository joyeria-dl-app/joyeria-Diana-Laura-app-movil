// TIPO: aceptación simulada (flujo)
// ALCANCE: HU-14 · criterio: el cliente consulta y cambia su perfil y revisa su historial de pedidos y apartados
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/perfil_flujo_test.dart
// DATOS: backend simulado en memoria a nivel HTTP (sin red); cuenta, pedidos y apartado de ejemplo

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/models/usuario.dart';
import 'package:joyeria_diana_laura/providers/tema_provider.dart';
import 'package:joyeria_diana_laura/screens/perfil_screen.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/auth_service.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/perfil_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// HU-14 · Criterio de aceptación: el cliente con sesión abre Mi perfil y ve sus datos y lo que
// lleva en la tienda; cambia su nombre, su teléfono y su foto; elige el tema claro; revisa el
// historial de sus pedidos (con el recibo del entregado) y de sus apartados (con cada abono), y
// cierra sesión. Corre la app completa con los servicios reales; lo que se simula es el backend,
// que responde por HTTP desde memoria y guarda los cambios como lo haría el servidor.

const _base = 'https://joyeria.example/api';
const _token = 'token-de-ana';

class _Servidor implements HttpClientAdapter {
  Map<String, Object?> cuenta = {
    'nombre': 'Ana Martínez',
    'email': 'ana.martinez@correo.com',
    'telefono': '7711234567',
    'foto_perfil_url': null,
    'fecha_creacion': '2026-10-02T15:20:00.000Z',
  };
  final List<String> peticiones = [];
  final List<Map<String, dynamic>> cambiosPerfil = [];
  final List<String> carpetasFoto = [];
  bool sesionVencida = false;

  static final _pedidos = [
    {
      'id': 51,
      'folio': 'DL-1791300000051',
      'estado': 'en_preparacion',
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
      ],
    },
    {
      'id': 42,
      'folio': 'DL-1791190000042',
      'estado': 'entregado',
      'total': '580.32',
      'costo_envio': '0',
      'tipo_entrega': 'tienda',
      'metodo_pago_nombre': 'MercadoPago',
      'metodo_pago_codigo': 'mercadopago',
      'estado_pago': 'aprobado',
      'fecha_creacion': '2026-10-05T16:15:00.000Z',
      'items': [
        {'producto_nombre': 'Cadena de plata', 'producto_imagen': null, 'cantidad': 1, 'precio_unitario': '580.32'},
      ],
      'historial': [
        {'estado': 'confirmado', 'fecha': '2026-10-05T18:40:00.000Z', 'comentario': null},
        {'estado': 'entregado', 'fecha': '2026-10-07T17:05:00.000Z', 'comentario': null},
      ],
    },
  ];

  static final _apartado = {
    'id': 7,
    'folio': 'APT-20261012-K3M8P',
    'estado': 'activo',
    'monto_total': '1250.00',
    'monto_pagado': '875.00',
    'saldo_pendiente': '375.00',
    'fecha_limite_liquidacion': '2026-11-09T06:00:00.000Z',
    'plan_nombre': 'Semanal',
    'productos': [
      {'nombre': 'Anillo lila halo', 'cantidad': 1, 'precio_unitario': '1250.00', 'imagen': null},
    ],
    'abonos': [
      {'id': 21, 'monto': '625.00', 'fecha_abono': '2026-10-12', 'estado': 'pagado', 'metodo_nombre': 'Efectivo en Tienda', 'metodo_codigo': 'efectivo'},
      {'id': 24, 'monto': '250.00', 'fecha_abono': '2026-10-19', 'estado': 'pagado', 'metodo_nombre': 'Transferencia Bancaria'},
    ],
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final ruta = '${options.method} ${options.path}';
    peticiones.add(ruta);
    if (options.headers['Authorization'] != 'Bearer $_token' || (sesionVencida && options.path != '/auth/logout')) {
      return _json(401, {'success': false, 'message': 'Token inválido'});
    }
    switch (ruta) {
      case 'GET /auth/profile':
        return _json(200, {'success': true, 'data': cuenta});
      case 'PUT /auth/profile':
        final datos = Map<String, dynamic>.from(options.data as Map);
        cambiosPerfil.add(datos);
        cuenta = {...cuenta, ...datos};
        return _json(200, {'success': true, 'message': 'Perfil actualizado correctamente'});
      case 'POST /upload/image':
        final campos = Map.fromEntries((options.data as FormData).fields);
        carpetasFoto.add(campos['folder']!);
        return _json(200, {
          'success': true,
          'data': {'url': 'https://res.cloudinary.com/tienda/image/upload/joyeria/usuarios/ana.jpg'},
        });
      case 'GET /carrito/pedidos/mis':
        return _json(200, {'success': true, 'data': _pedidos});
      case 'GET /apartados/mis-apartados':
        return _json(200, {
          'success': true,
          'data': [_apartado],
        });
      case 'GET /apartados/7':
        return _json(200, {'success': true, 'data': _apartado});
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

class _App {
  _App(this.servidor, this.storage, this.tema);
  final _Servidor servidor;
  final MemorySessionStorage storage;
  final MemoriaPreferenciaTema tema;
  final List<Uri> recibos = [];
}

Future<_App> _abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  addTearDown(() => AppColors.usar(Paleta.oscuraBoceto));

  final servidor = _Servidor();
  final storage = MemorySessionStorage();
  await storage.guardar(_token, const Usuario(email: 'ana.martinez@correo.com', nombre: 'Ana Martínez', rol: 'cliente'));
  final api = ApiClient(
    dio: Dio(BaseOptions(baseUrl: _base))..httpClientAdapter = servidor,
    storage: storage,
  );
  final pedidos = PedidoService(api: api);
  final favoritos = FavoritoService(api: api);
  final app = _App(servidor, storage, MemoriaPreferenciaTema());

  abrirRecibo = (uri) async {
    app.recibos.add(uri);
    return true;
  };
  elegirFotoPerfil = (_) async => XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'ana.jpg', path: 'ana.jpg');

  await tester.pumpWidget(
    JoyeriaApp(
      storage: storage,
      authService: AuthService(api: api, storage: storage),
      carritoService: CarritoService(api: api),
      favoritoService: favoritos,
      pedidoService: pedidos,
      perfilService: PerfilService(api: api, pedidos: pedidos, favoritos: favoritos),
      preferenciaTema: app.tema,
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

Future<void> _irAlPerfil(WidgetTester tester) async {
  await _tocar(tester, find.byKey(const Key('nav_perfil')));
  expect(find.text('Mi perfil'), findsOneWidget);
}

Future<void> _escribir(WidgetTester tester, String campo, String texto) =>
    tester.enterText(find.descendant(of: find.byKey(Key(campo)), matching: find.byType(TextFormField)), texto);

void main() {
  testWidgets('Desde el inicio abre Mi perfil con sus datos y lo que lleva en la tienda', (tester) async {
    final app = await _abrir(tester);
    await _irAlPerfil(tester);

    expect(find.text('Ana Martínez'), findsOneWidget);
    expect(find.text('ana.martinez@correo.com'), findsOneWidget);
    expect(find.text('Clienta desde oct 2026'), findsOneWidget);
    for (final (numero, nombre) in [('2', 'Pedidos'), ('1', 'Apartados'), ('0', 'Favoritos')]) {
      expect(find.text(numero), findsOneWidget, reason: nombre);
    }
    expect(app.servidor.peticiones, containsAll(['GET /auth/profile', 'GET /carrito/pedidos/mis', 'GET /apartados/mis-apartados', 'GET /favoritos']));
  });

  testWidgets('Cambia su nombre y su teléfono en Ajustes y Mi perfil muestra los nuevos', (tester) async {
    final app = await _abrir(tester);
    await _irAlPerfil(tester);
    await _tocar(tester, find.byTooltip('Ajustes'));

    await _escribir(tester, 'ajustes_nombre', 'Ana Laura Martínez');
    await _escribir(tester, 'ajustes_telefono', '771-765-4321');
    await _tocar(tester, find.byKey(const Key('ajustes_guardar')));

    expect(app.servidor.cambiosPerfil, [
      {'nombre': 'Ana Laura Martínez', 'telefono': '7717654321'},
    ]);
    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Ana Laura Martínez'), findsOneWidget);
    expect(find.text('Tus datos se guardaron'), findsOneWidget);

    // Al volver a Ajustes ya aparecen los datos guardados en el servidor.
    await _tocar(tester, find.byTooltip('Ajustes'));
    expect(find.text('7717654321'), findsOneWidget);
  });

  testWidgets('Cambia su foto: se sube a la carpeta de usuarios y se guarda en su perfil', (tester) async {
    final app = await _abrir(tester);
    await _irAlPerfil(tester);
    await _tocar(tester, find.byKey(const Key('perfil_foto')));
    await _tocar(tester, find.byKey(const Key('foto_galeria')));

    expect(app.servidor.carpetasFoto, ['joyeria/usuarios']);
    expect(app.servidor.cambiosPerfil, [
      {'foto_perfil_url': 'https://res.cloudinary.com/tienda/image/upload/joyeria/usuarios/ana.jpg'},
    ]);
    expect(find.text('Tu foto se actualizó'), findsOneWidget);
  });

  testWidgets('Elige el tema claro y la preferencia queda guardada para la próxima vez', (tester) async {
    final app = await _abrir(tester);
    await _irAlPerfil(tester);
    await _tocar(tester, find.byKey(const Key('perfil_tema')));

    expect(AppColors.fondo, Paleta.claraBoceto.fondo);
    expect(tester.widget<Switch>(find.byKey(const Key('perfil_tema'))).value, isFalse);
    expect(await app.tema.leerOscuro(), isFalse);

    // El resto de la app también cambia: Mis pedidos se abre ya con el fondo claro.
    await _tocar(tester, find.text('Mis pedidos'));
    expect(Theme.of(tester.element(find.text('Mis pedidos').first)).scaffoldBackgroundColor, Paleta.claraBoceto.fondo);
  });

  testWidgets('Revisa el historial de pedidos y abre el recibo del pedido entregado', (tester) async {
    final app = await _abrir(tester);
    await _irAlPerfil(tester);
    await _tocar(tester, find.text('Mis pedidos'));

    expect(find.textContaining('DL-1791300000051'), findsOneWidget);
    await _tocar(tester, find.textContaining('Entregados'));
    await _tocar(tester, find.textContaining('DL-1791190000042'));
    expect(find.byType(SeguimientoScreen), findsOneWidget);
    expect(find.text('Recibo de tu compra'), findsOneWidget);

    await _tocar(tester, find.byTooltip('Ver o descargar recibo'));
    expect(app.recibos.single.toString(), '$_base/carrito/pedidos/42/recibo?token=$_token');
  });

  testWidgets('Revisa el historial de un apartado con cada abono y su método de pago', (tester) async {
    final app = await _abrir(tester);
    await _irAlPerfil(tester);
    await _tocar(tester, find.text('Mis apartados'));
    await _tocar(tester, find.textContaining('APT-20261012-K3M8P'));

    expect(app.servidor.peticiones, contains('GET /apartados/7'));
    expect(find.text('Mi apartado'), findsOneWidget);
    expect(find.text('Abonos · 2'), findsOneWidget);
    expect(find.text('12 oct · Efectivo en Tienda'), findsOneWidget);
    expect(find.text('19 oct · Transferencia Bancaria'), findsOneWidget);
    expect(find.text(r'Faltan $375.00'), findsOneWidget);
  });

  testWidgets('Cierra sesión desde Mi perfil: avisa al backend y el teléfono ya no guarda la sesión', (tester) async {
    final app = await _abrir(tester);
    await _irAlPerfil(tester);
    await _tocar(tester, find.text('Cerrar sesión'));
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    await _tocar(tester, find.widgetWithText(TextButton, 'Cerrar sesión'));

    expect(app.servidor.peticiones, contains('POST /auth/logout'));
    expect(await app.storage.leerToken(), isNull);
    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.byType(PerfilScreen), findsNothing);
  });

  testWidgets('Si la sesión venció, Mi perfil invita a iniciarla de nuevo', (tester) async {
    final app = await _abrir(tester);
    app.servidor.sesionVencida = true;
    await _tocar(tester, find.byKey(const Key('nav_perfil')));

    expect(find.text('Inicia sesión para ver tu perfil'), findsOneWidget);
    // El login se revisa con la vista de prueba por defecto, como en login_screen_test.dart: la fuente
    // de prueba de Flutter es más ancha que Poppins y en una vista de teléfono desborda el renglón.
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await _tocar(tester, find.text('Iniciar sesión').last);
    expect(find.byKey(const Key('login_email')), findsOneWidget);
  });
}
