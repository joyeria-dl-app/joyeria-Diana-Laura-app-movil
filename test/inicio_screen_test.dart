// TIPO: widget (flujo)
// ALCANCE: #244 · Inicio del boceto P5: saludo, buscador, carrusel, categorías, piezas destacadas y barra de 5 pestañas
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/inicio_screen_test.dart
// DATOS: backend simulado en memoria a nivel HTTP (sin red) con la forma real de producción: categorías, carrusel del sitio web y catálogo

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/models/usuario.dart';
import 'package:joyeria_diana_laura/screens/catalogo_screen.dart';
import 'package:joyeria_diana_laura/screens/zonas_entrega_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

const _base = 'https://joyeria.example/api';
const _token = 'token-de-ana';

class _Servidor implements HttpClientAdapter {
  bool caido = false;
  final List<RequestOptions> peticiones = [];

  static final _categorias = [
    {'id': 1, 'nombre': 'Anillos', 'activo': true, 'categoria_padre_id': null},
    {'id': 2, 'nombre': 'collares', 'activo': true, 'categoria_padre_id': null},
    {'id': 3, 'nombre': 'Relojes', 'activo': false, 'categoria_padre_id': null},
  ];

  // Como lo devuelve /content/carrusel-inicio (lista, sin envoltura).
  static final _carrusel = [
    {
      'id': 8,
      'titulo': 'Colección Exclusiva',
      'descripcion': 'Piezas únicas para cada ocasión',
      'imagen_url': 'https://res.cloudinary.com/t/image/upload/a.jpg',
      'enlace_url': '/catalogo-publico',
      'activo': true,
    },
    {
      'id': 2,
      'titulo': 'Donde nos ubicamos',
      'descripcion': 'Ubicación de nuestro local',
      'imagen_url': 'https://res.cloudinary.com/t/image/upload/b.jpg',
      'enlace_url': 'http://localhost:3000/ubicacion-publica',
      'activo': true,
    },
    {'id': 9, 'titulo': 'Sin foto', 'descripcion': 'No se muestra', 'imagen_url': null, 'activo': true},
  ];

  static Map<String, Object?> _pieza(int id, String nombre, String precio, {int stock = 3, int categoria = 1}) => {
    'id': id,
    'nombre': nombre,
    'precio_venta': precio,
    'imagen_principal': null,
    'categoria_id': categoria,
    'stock_actual': stock,
  };

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    if (caido) return _json(503, {'success': false});
    switch ('${options.method} ${options.path}') {
      case 'GET /products/categorias':
        return _json(200, {'success': true, 'data': _categorias});
      case 'GET /content/carrusel-inicio':
        return _json(200, _carrusel);
      case 'GET /products/filter':
        final categoria = options.queryParameters['categoria_id'];
        final nombre = options.queryParameters['nombre'] as String?;
        final piezas =
            [
                  _pieza(10, 'Anillo agotado', '300.00', stock: 0),
                  _pieza(11, 'Anillo de promesa', '449.50'),
                  _pieza(12, 'Collar de perlas', '890.00', categoria: 2),
                ]
                .where((p) => categoria == null || p['categoria_id'] == categoria)
                .where((p) => nombre == null || (p['nombre']! as String).toLowerCase().contains(nombre.toLowerCase()));
        return _json(200, {'success': true, 'data': piezas.toList()});
      case 'GET /carrito':
        return _json(200, {
          'success': true,
          'data': {
            'items': [
              {'id': 1, 'producto_id': 11, 'producto_nombre': 'Anillo de promesa', 'cantidad': 2, 'precio_venta': '449.50', 'stock_actual': 3},
            ],
            'total': 899,
          },
        });
      case 'GET /favoritos':
        return _json(200, {'success': true, 'data': <Object>[]});
    }
    return _json(404, {'success': false, 'message': 'Ruta no simulada'});
  }

  ResponseBody _json(int status, Object cuerpo) => ResponseBody.fromString(
    jsonEncode(cuerpo),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

Future<_Servidor> _abrir(WidgetTester tester, {bool conSesion = true, _Servidor? servidor}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final s = servidor ?? _Servidor();
  final storage = MemorySessionStorage();
  if (conSesion) await storage.guardar(_token, const Usuario(email: 'ana.martinez@correo.com', nombre: 'Ana Martínez', rol: 'cliente'));
  final api = ApiClient(
    dio: Dio(BaseOptions(baseUrl: _base))..httpClientAdapter = s,
    storage: storage,
  );
  await tester.pumpWidget(JoyeriaApp(storage: storage, apiClient: api));
  await tester.pumpAndSettle();
  return s;
}

Future<void> _tocar(WidgetTester tester, Finder boton) async {
  await tester.ensureVisible(boton);
  await tester.pumpAndSettle();
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Con sesión saluda por su nombre y deja abrir los avisos de sus pedidos', (tester) async {
    await _abrir(tester);

    expect(find.descendant(of: find.byKey(const Key('inicio_saludo')), matching: find.text('Ana Martínez')), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.byKey(const Key('inicio_notificaciones')), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('Sin sesión invita a iniciar sesión o crear cuenta y no muestra notificaciones', (tester) async {
    await _abrir(tester, conSesion: false);

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Explorar sin cuenta'), findsOneWidget);
    expect(find.byKey(const Key('inicio_notificaciones')), findsNothing);
    // El resto del Inicio se ve igual.
    expect(find.text('Colección Exclusiva'), findsOneWidget);
  });

  testWidgets('El carrusel muestra los banners del sitio web y omite los que no tienen foto', (tester) async {
    final servidor = await _abrir(tester);

    expect(servidor.peticiones.map((p) => p.path), contains('/content/carrusel-inicio'));
    expect(find.text('Colección Exclusiva'), findsOneWidget);
    expect(find.text('Piezas únicas para cada ocasión'), findsOneWidget);
    expect(find.text('Sin foto'), findsNothing);
  });

  testWidgets('El banner de la ubicación abre Zonas de entrega', (tester) async {
    await _abrir(tester);
    await tester.drag(find.byKey(const Key('inicio_carrusel')), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await _tocar(tester, find.text('Donde nos ubicamos'));

    expect(find.byType(ZonasEntregaScreen), findsOneWidget);
  });

  testWidgets('Muestra las categorías activas y cada chip abre el catálogo ya filtrado', (tester) async {
    final servidor = await _abrir(tester);
    expect(find.text('Todo'), findsOneWidget);
    expect(find.text('Collares'), findsOneWidget);
    expect(find.text('Relojes'), findsNothing);

    await _tocar(tester, find.text('Collares'));

    expect(find.byType(CatalogoScreen), findsOneWidget);
    expect(servidor.peticiones.last.queryParameters['categoria_id'], 2);
    expect(find.text('Collar de perlas'), findsOneWidget);
    expect(find.text('Anillo de promesa'), findsNothing);
  });

  testWidgets('Para ti muestra las piezas del catálogo con su precio, primero las que tienen existencias', (tester) async {
    await _abrir(tester);

    expect(find.text('Para ti'), findsOneWidget);
    expect(find.text(r'$449.50'), findsOneWidget);
    expect(find.text(r'$890'), findsOneWidget);
    final promesa = tester.getTopLeft(find.text('Anillo de promesa')).dx;
    final agotado = tester.getTopLeft(find.text('Anillo agotado')).dx;
    expect(promesa, lessThan(agotado));
  });

  testWidgets('El buscador abre el catálogo listo para escribir y busca por nombre', (tester) async {
    final servidor = await _abrir(tester);
    await _tocar(tester, find.byKey(const Key('inicio_buscar')));

    expect(find.byType(CatalogoScreen), findsOneWidget);
    await tester.enterText(find.byKey(const Key('catalogo_busqueda')), 'perlas');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(servidor.peticiones.last.queryParameters['nombre'], 'perlas');
    expect(find.text('Collar de perlas'), findsOneWidget);
    expect(find.text('Anillo de promesa'), findsNothing);
  });

  testWidgets('La barra tiene las 5 pestañas y el carrito muestra cuántas piezas lleva', (tester) async {
    await _abrir(tester);

    for (final pestana in ['inicio', 'catalogo', 'carrito', 'favoritos', 'perfil']) {
      expect(find.byKey(Key('nav_$pestana')), findsOneWidget, reason: pestana);
    }
    expect(find.descendant(of: find.byKey(const Key('nav_carrito')), matching: find.text('2')), findsOneWidget);
  });

  testWidgets('Los accesos de la cuenta ya no están en el Inicio sino en Mi perfil', (tester) async {
    await _abrir(tester);

    for (final acceso in ['Mis pedidos', 'Mis apartados', 'Mis personalizaciones', 'Zonas de entrega', 'Cerrar sesión']) {
      expect(find.text(acceso), findsNothing, reason: acceso);
    }
  });

  testWidgets('Sin conexión deja reintentar y entonces muestra el Inicio', (tester) async {
    final servidor = await _abrir(tester, servidor: _Servidor()..caido = true);
    expect(find.text('Sin conexión'), findsOneWidget);

    servidor.caido = false;
    await _tocar(tester, find.text('Reintentar'));
    expect(find.text('Colección Exclusiva'), findsOneWidget);
    expect(find.text('Para ti'), findsOneWidget);
  });
}
