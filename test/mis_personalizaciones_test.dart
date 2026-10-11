import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/personalizacion.dart';
import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/screens/mis_personalizaciones_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/personalizacion_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// HU-13 · Consultar el estado de mis solicitudes de personalización (#48).

class _PersonalizacionFalsa extends PersonalizacionService {
  _PersonalizacionFalsa({this.solicitudes = const [], this.error}) : super(api: ApiClient());
  List<SolicitudPersonalizacion> solicitudes;
  PersonalizacionException? error;
  int consultas = 0;

  @override
  Future<List<SolicitudPersonalizacion>> misSolicitudes() async {
    consultas++;
    if (error != null) throw error!;
    return solicitudes;
  }
}

class _ProductosFalsos extends ProductoService {
  _ProductosFalsos() : super(api: ApiClient());

  @override
  Future<DetalleProducto> detalle(int id) async => DetalleProducto(
    producto: Producto(id: id, nombre: 'Esclava de plata', precioVenta: 900.55, stock: 10, personalizable: true),
  );

  @override
  Future<({double promedio, int total})> resenas(int id) async => (promedio: 0.0, total: 0);
}

final _pendiente = SolicitudPersonalizacion(
  id: 12,
  productoId: 1,
  productoNombre: 'Esclava personalizada Día del Padre',
  detalle: 'Grabar el nombre "Marcos" por dentro, en letra cursiva.',
  estado: EstadoSolicitud.pendiente,
  fechaCreacion: DateTime(2026, 10, 11, 7, 56),
);

final _aprobada = SolicitudPersonalizacion(
  id: 9,
  productoId: 88,
  productoNombre: 'Esclava de plata',
  detalle: 'Nombre "Valentina" en la placa.',
  estado: EstadoSolicitud.aprobada,
  precioPersonalizacion: 150,
  fechaCreacion: DateTime(2026, 10, 2),
  fechaRespuesta: DateTime(2026, 10, 3),
);

final _rechazada = SolicitudPersonalizacion(
  id: 7,
  productoId: 61,
  productoNombre: 'Collar corazón',
  detalle: 'Cambiar la cadena por una de 60 cm.',
  estado: EstadoSolicitud.rechazada,
  motivoRechazo: 'La cadena de 60 cm no está disponible para este modelo.',
  fechaCreacion: DateTime(2026, 9, 28),
  fechaRespuesta: DateTime(2026, 9, 29),
);

Future<void> _abrir(WidgetTester tester, PersonalizacionService servicio) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PersonalizacionService>.value(value: servicio),
        Provider<ProductoService>.value(value: _ProductosFalsos()),
      ],
      child: MaterialApp(
        theme: AppTheme.oscuro(),
        home: const MisPersonalizacionesScreen(),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Pantalla de login')),
          '/catalogo': (_) => const Scaffold(body: Text('Pantalla del catálogo')),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Muestra cada solicitud con su estado y cuántas están en revisión', (tester) async {
    await _abrir(tester, _PersonalizacionFalsa(solicitudes: [_pendiente, _aprobada, _rechazada]));

    expect(find.text('3 solicitudes · 1 en revisión'), findsOneWidget);
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Aprobada'), findsOneWidget);
    expect(find.text('No aprobada'), findsOneWidget);
    expect(find.text('Grabar el nombre "Marcos" por dentro, en letra cursiva.'), findsOneWidget);
    expect(find.text('Pedida el 11 oct'), findsOneWidget);
  });

  testWidgets('En revisión avisa que la tienda la está revisando', (tester) async {
    await _abrir(tester, _PersonalizacionFalsa(solicitudes: [_pendiente]));
    expect(find.text('1 solicitud · 1 en revisión'), findsOneWidget);
    expect(find.text('La tienda está revisando tu solicitud. Te avisaremos por correo.'), findsOneWidget);
    expect(find.text('Ver pieza'), findsNothing);
  });

  testWidgets('Aprobada muestra el costo extra, la fecha de respuesta y lleva a la pieza', (tester) async {
    await _abrir(tester, _PersonalizacionFalsa(solicitudes: [_aprobada]));
    expect(find.text(r'Pedida el 2 oct · +$150'), findsOneWidget);
    expect(find.text('La tienda aprobó tu personalización el 3 oct. Ya puedes comprar la pieza.'), findsOneWidget);

    await tester.tap(find.text('Ver pieza'));
    await tester.pumpAndSettle();
    expect(find.byType(DetalleScreen), findsOneWidget);
  });

  testWidgets('No aprobada muestra el motivo de la tienda y deja intentar otra', (tester) async {
    await _abrir(tester, _PersonalizacionFalsa(solicitudes: [_rechazada]));
    expect(find.text('Motivo el 29 sep: La cadena de 60 cm no está disponible para este modelo.'), findsOneWidget);
    expect(find.text('Intentar otra'), findsOneWidget);
  });

  testWidgets('Aprobada y ya usada en una compra aparece como comprada', (tester) async {
    final usada = SolicitudPersonalizacion(
      id: 3,
      productoId: 88,
      productoNombre: 'Esclava de plata',
      detalle: 'Nombre "Ana" en la placa.',
      estado: EstadoSolicitud.aprobada,
      utilizada: true,
    );
    await _abrir(tester, _PersonalizacionFalsa(solicitudes: [usada]));
    expect(find.text('Comprada'), findsOneWidget);
    expect(find.text('Ya compraste esta pieza con tu personalización.'), findsOneWidget);
    expect(find.text('Ver pieza'), findsNothing);
  });

  testWidgets('Sin solicitudes invita a ver el catálogo', (tester) async {
    await _abrir(tester, _PersonalizacionFalsa());
    expect(find.text('Aún no pides personalizaciones'), findsOneWidget);
    await tester.tap(find.text('Ver catálogo'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla del catálogo'), findsOneWidget);
  });

  testWidgets('Sin sesión invita a iniciarla', (tester) async {
    await _abrir(tester, _PersonalizacionFalsa(error: const PersonalizacionException('Inicia sesión para solicitar una personalización.', sinSesion: true)));
    expect(find.text('Inicia sesión para ver tus personalizaciones'), findsOneWidget);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla de login'), findsOneWidget);
  });

  testWidgets('Sin conexión deja reintentar y entonces muestra las solicitudes', (tester) async {
    final servicio = _PersonalizacionFalsa(error: const PersonalizacionException('No se pudo conectar. Revisa tu conexión e intenta de nuevo.'));
    await _abrir(tester, servicio);
    expect(find.text('Sin conexión'), findsOneWidget);

    servicio
      ..error = null
      ..solicitudes = [_pendiente];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(servicio.consultas, 2);
    expect(find.text('En revisión'), findsOneWidget);
  });
}
