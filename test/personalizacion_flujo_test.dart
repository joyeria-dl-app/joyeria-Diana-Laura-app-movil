import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/personalizacion.dart';
import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/screens/mis_personalizaciones_screen.dart';
import 'package:joyeria_diana_laura/screens/solicitar_personalizacion_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/personalizacion_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// HU-13 · Criterio de aceptación: el cliente pide la personalización de una pieza desde
// su detalle, la ve "En revisión" en Mis personalizaciones y, cuando la tienda responde,
// ve si quedó aprobada (con el costo extra) o no aprobada (con el motivo). El backend se
// simula en memoria; la prueba hace de trabajador al aprobar o rechazar la solicitud.

class _Backend extends PersonalizacionService {
  _Backend() : super(api: ApiClient());
  final List<SolicitudPersonalizacion> solicitudes = [];
  // Respuesta del backend al enviar (por ejemplo, sesión vencida o servidor caído).
  PersonalizacionException? error;
  int _siguiente = 1;

  @override
  Future<SolicitudEnviada> solicitar({required int productoId, required String detalle, String? imagenReferencia}) async {
    if (error != null) throw error!;
    final s = SolicitudPersonalizacion(
      id: _siguiente++,
      productoId: productoId,
      productoNombre: 'Anillo corazón',
      precioPersonalizacion: 150,
      detalle: detalle.trim(),
      estado: EstadoSolicitud.pendiente,
      fechaCreacion: DateTime(2026, 10, 20, 10, 30),
    );
    solicitudes.insert(0, s);
    return SolicitudEnviada(solicitud: s, diasEstimados: 3);
  }

  @override
  Future<List<SolicitudPersonalizacion>> misSolicitudes() async {
    if (error != null) throw error!;
    return List.of(solicitudes);
  }

  // Pantalla del trabajador en el sitio web: aprueba o rechaza la solicitud.
  void responder(int id, EstadoSolicitud estado, {String? motivo}) {
    final i = solicitudes.indexWhere((s) => s.id == id);
    final s = solicitudes[i];
    solicitudes[i] = SolicitudPersonalizacion(
      id: s.id,
      productoId: s.productoId,
      productoNombre: s.productoNombre,
      precioPersonalizacion: s.precioPersonalizacion,
      detalle: s.detalle,
      estado: estado,
      motivoRechazo: motivo,
      fechaCreacion: s.fechaCreacion,
      fechaRespuesta: DateTime(2026, 10, 21, 9),
    );
  }
}

class _Productos extends ProductoService {
  _Productos() : super(api: ApiClient());

  @override
  Future<DetalleProducto> detalle(int id) async => DetalleProducto(
    producto: Producto(id: id, nombre: 'Anillo corazón', precioVenta: 1250, stock: 3, personalizable: true),
    descripcion: 'Plata .925 con circonia rosa.',
    precioPersonalizacion: 150,
  );

  @override
  Future<({double promedio, int total})> resenas(int id) async => (promedio: 0.0, total: 0);
}

final _navegador = GlobalKey<NavigatorState>();

Future<void> _abrir(WidgetTester tester, _Backend backend) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PersonalizacionService>.value(value: backend),
        Provider<ProductoService>.value(value: _Productos()),
      ],
      child: MaterialApp(
        navigatorKey: _navegador,
        theme: AppTheme.oscuro(),
        home: const DetalleScreen(productoId: 58),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Pantalla de login')),
          '/catalogo': (_) => const Scaffold(body: Text('Pantalla del catálogo')),
          '/mis-personalizaciones': (_) => const MisPersonalizacionesScreen(),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _campo => find.descendant(of: find.byKey(const Key('personalizacion_detalle')), matching: find.byType(EditableText));

// Desde el detalle de la pieza: tarjeta "Personalizar", escribe el detalle y envía.
Future<void> _pedir(WidgetTester tester, String detalle) async {
  await tester.tap(find.bySemanticsLabel('Personalizar esta pieza'));
  await tester.pumpAndSettle();
  await tester.enterText(_campo, detalle);
  await tester.pump();
  await tester.tap(find.text('Enviar solicitud'));
  await tester.pumpAndSettle();
}

// Abre Mis personalizaciones encima de lo que esté en pantalla.
Future<void> _misPersonalizaciones(WidgetTester tester) async {
  _navegador.currentState!.pushNamed('/mis-personalizaciones');
  await tester.pumpAndSettle();
}

Future<void> _regresar(WidgetTester tester) async {
  _navegador.currentState!.pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Pide la personalización desde el detalle y la ve en revisión', (tester) async {
    final backend = _Backend();
    await _abrir(tester, backend);

    await _pedir(tester, 'Grabar las iniciales D & L por dentro');
    expect(find.text('¡Solicitud enviada!'), findsOneWidget);
    expect(backend.solicitudes.single.detalle, 'Grabar las iniciales D & L por dentro');

    await tester.tap(find.text('Volver a la pieza'));
    await tester.pumpAndSettle();
    expect(find.byType(DetalleScreen), findsOneWidget);

    await _misPersonalizaciones(tester);
    expect(find.text('1 solicitud · 1 en revisión'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Grabar las iniciales D & L por dentro'), findsOneWidget);
  });

  testWidgets('Cuando la tienda la aprueba ve el costo extra y puede ir a comprar la pieza', (tester) async {
    final backend = _Backend();
    await _abrir(tester, backend);
    await _pedir(tester, 'Grabar el nombre "Laura" en cursiva');
    await _regresar(tester);

    backend.responder(1, EstadoSolicitud.aprobada);
    await _misPersonalizaciones(tester);
    expect(find.text('Aprobada'), findsOneWidget);
    expect(find.text(r'Pedida el 20 oct · +$150'), findsOneWidget);
    expect(find.text('La tienda aprobó tu personalización el 21 oct. Ya puedes comprar la pieza.'), findsOneWidget);

    await tester.tap(find.text('Ver pieza'));
    await tester.pumpAndSettle();
    expect(find.byType(DetalleScreen), findsOneWidget);
  });

  testWidgets('Cuando la tienda no la aprueba ve el motivo y puede pedir otra', (tester) async {
    final backend = _Backend();
    await _abrir(tester, backend);
    await _pedir(tester, 'Cambiar la piedra por una esmeralda');
    await _regresar(tester);

    backend.responder(1, EstadoSolicitud.rechazada, motivo: 'No manejamos esmeraldas para este modelo.');
    await _misPersonalizaciones(tester);
    expect(find.text('No aprobada'), findsOneWidget);
    expect(find.text('Motivo el 21 oct: No manejamos esmeraldas para este modelo.'), findsOneWidget);

    await tester.tap(find.text('Intentar otra'));
    await tester.pumpAndSettle();
    await _pedir(tester, 'Cambiar la piedra por una circonia verde');
    expect(find.text('¡Solicitud enviada!'), findsOneWidget);
    expect(backend.solicitudes.map((s) => s.estado), [EstadoSolicitud.pendiente, EstadoSolicitud.rechazada]);
  });

  testWidgets('Con un detalle muy corto no se envía nada al backend', (tester) async {
    final backend = _Backend();
    await _abrir(tester, backend);
    await _pedir(tester, 'Grabado');

    expect(find.text('Escribe al menos 10 caracteres (7/10).'), findsOneWidget);
    expect(find.byType(SolicitarPersonalizacionScreen), findsOneWidget);
    expect(backend.solicitudes, isEmpty);
  });

  testWidgets('Si el servidor falla no se pierde lo escrito y puede reintentar', (tester) async {
    final backend = _Backend()..error = const PersonalizacionException('No se pudo conectar. Revisa tu conexión e intenta de nuevo.');
    await _abrir(tester, backend);
    await _pedir(tester, 'Grabar la fecha 14/02/2027');

    expect(find.text('No se pudo conectar. Revisa tu conexión e intenta de nuevo.'), findsOneWidget);
    expect(find.text('Grabar la fecha 14/02/2027'), findsOneWidget);

    backend.error = null;
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();
    expect(find.text('¡Solicitud enviada!'), findsOneWidget);
    expect(backend.solicitudes, hasLength(1));
  });

  testWidgets('Sin sesión no se guarda la solicitud y lo lleva a iniciar sesión', (tester) async {
    final backend = _Backend()..error = const PersonalizacionException('Inicia sesión para solicitar una personalización.', sinSesion: true);
    await _abrir(tester, backend);
    await _pedir(tester, 'Grabar las iniciales D & L');

    expect(backend.solicitudes, isEmpty);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla de login'), findsOneWidget);
  });
}
