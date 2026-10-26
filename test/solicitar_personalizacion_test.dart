// TIPO: widget
// ALCANCE: HU-13 · formulario de solicitud y tarjeta del detalle
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/solicitar_personalizacion_test.dart
// DATOS: backend simulado en memoria (sin red); anillo de ejemplo y foto PNG de 1×1

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/personalizacion.dart';
import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/screens/solicitar_personalizacion_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/personalizacion_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// HU-13 · Formulario de solicitud de personalización (#46).

// Backend de personalización en memoria: guarda lo enviado o falla como se le indique.
class _PersonalizacionFalsa extends PersonalizacionService {
  _PersonalizacionFalsa({this.error, this.dias = 3}) : super(api: ApiClient());
  PersonalizacionException? error;
  final int dias;
  final List<({int productoId, String detalle, String? imagen})> enviadas = [];
  final List<String> subidas = [];

  @override
  Future<SolicitudEnviada> solicitar({required int productoId, required String detalle, String? imagenReferencia}) async {
    if (error != null) throw error!;
    enviadas.add((productoId: productoId, detalle: detalle.trim(), imagen: imagenReferencia));
    return SolicitudEnviada(
      solicitud: SolicitudPersonalizacion(
        id: 12,
        productoId: productoId,
        productoNombre: 'Anillo corazón',
        detalle: detalle.trim(),
        estado: EstadoSolicitud.pendiente,
      ),
      diasEstimados: dias,
    );
  }

  @override
  Future<String> subirReferencia(List<int> bytes, String nombreArchivo) async {
    subidas.add(nombreArchivo);
    return 'https://res.cloudinary.com/demo/joyeria/personalizaciones/$nombreArchivo';
  }
}

class _ProductosFalsos extends ProductoService {
  _ProductosFalsos(this.detalleFalso) : super(api: ApiClient());
  final DetalleProducto detalleFalso;

  @override
  Future<DetalleProducto> detalle(int id) async => detalleFalso;

  @override
  Future<({double promedio, int total})> resenas(int id) async => (promedio: 0.0, total: 0);
}

const _anillo = Producto(id: 58, nombre: 'Anillo corazón', precioVenta: 1250, stock: 3, personalizable: true);

DetalleProducto _detalle({bool personalizable = true, int stock = 3, double precioPersonalizacion = 150}) => DetalleProducto(
  producto: Producto(id: 58, nombre: 'Anillo corazón', precioVenta: 1250, stock: stock, personalizable: personalizable),
  descripcion: 'Plata .925 con circonia rosa.',
  precioPersonalizacion: precioPersonalizacion,
);

Future<void> _abrir(WidgetTester tester, PersonalizacionService servicio, Widget pantalla, {ProductoService? productos}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PersonalizacionService>.value(value: servicio),
        Provider<ProductoService>.value(value: productos ?? _ProductosFalsos(_detalle())),
      ],
      child: MaterialApp(
        theme: AppTheme.oscuro(),
        home: pantalla,
        routes: {'/login': (_) => const Scaffold(body: Text('Pantalla de login'))},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _campo => find.descendant(of: find.byKey(const Key('personalizacion_detalle')), matching: find.byType(EditableText));

void main() {
  late Future<XFile?> Function(ImageSource) original;
  final origenes = <ImageSource>[];

  setUp(() {
    origenes.clear();
    original = elegirFotoReferencia;
    elegirFotoReferencia = (origen) async {
      origenes.add(origen);
      return XFile.fromData(Uint8List.fromList(_png), name: 'referencia.png', path: 'referencia.png', mimeType: 'image/png');
    };
  });
  tearDown(() => elegirFotoReferencia = original);

  group('Desde el detalle de la pieza', () {
    testWidgets('Una pieza personalizable muestra la invitación con el costo extra y abre el formulario', (tester) async {
      await _abrir(tester, _PersonalizacionFalsa(), const DetalleScreen(productoId: 58));
      expect(find.text('¿La quieres a tu gusto?'), findsOneWidget);
      expect(find.text(r'Pide un grabado o un cambio · +$150'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Personalizar esta pieza'));
      await tester.pumpAndSettle();
      expect(find.byType(SolicitarPersonalizacionScreen), findsOneWidget);
      expect(find.text('Anillo corazón'), findsOneWidget);
    });

    testWidgets('Una pieza que no se personaliza o agotada no muestra la invitación', (tester) async {
      for (final d in [_detalle(personalizable: false), _detalle(stock: 0)]) {
        await _abrir(tester, _PersonalizacionFalsa(), const DetalleScreen(productoId: 58), productos: _ProductosFalsos(d));
        expect(find.text('¿La quieres a tu gusto?'), findsNothing);
      }
    });
  });

  group('Formulario', () {
    testWidgets('Con menos de 10 caracteres no deja enviar y avisa cuántos faltan', (tester) async {
      final servicio = _PersonalizacionFalsa();
      await _abrir(tester, servicio, const SolicitarPersonalizacionScreen(producto: _anillo));

      await tester.enterText(_campo, 'Grabado');
      await tester.pump();
      expect(find.text('Escribe al menos 10 caracteres (7/10).'), findsOneWidget);
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();
      expect(servicio.enviadas, isEmpty);
    });

    testWidgets('Envía el detalle y muestra la confirmación con los días de revisión', (tester) async {
      final servicio = _PersonalizacionFalsa(dias: 2);
      await _abrir(tester, servicio, const SolicitarPersonalizacionScreen(producto: _anillo));

      await tester.enterText(_campo, '  Grabar las iniciales D & L por dentro  ');
      await tester.pump();
      expect(find.text('37/1000'), findsOneWidget);
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();

      expect(servicio.enviadas.single, (productoId: 58, detalle: 'Grabar las iniciales D & L por dentro', imagen: null));
      expect(find.text('¡Solicitud enviada!'), findsOneWidget);
      expect(find.textContaining('en 2 días hábiles'), findsOneWidget);
    });

    testWidgets('Con foto de referencia la sube primero y manda su URL', (tester) async {
      final servicio = _PersonalizacionFalsa();
      await _abrir(tester, servicio, const SolicitarPersonalizacionScreen(producto: _anillo));

      await tester.tap(find.bySemanticsLabel('Agregar foto de referencia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomar foto'));
      await tester.pumpAndSettle();
      expect(origenes, [ImageSource.camera]);
      expect(find.byTooltip('Quitar foto'), findsOneWidget);

      await tester.enterText(_campo, 'Una piedra azul como en la foto');
      await tester.pump();
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();

      expect(servicio.subidas, ['referencia.png']);
      expect(servicio.enviadas.single.imagen, endsWith('/referencia.png'));
    });

    testWidgets('Quitar la foto la elimina antes de enviar', (tester) async {
      final servicio = _PersonalizacionFalsa();
      await _abrir(tester, servicio, const SolicitarPersonalizacionScreen(producto: _anillo));

      await tester.tap(find.bySemanticsLabel('Agregar foto de referencia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quitar foto'));
      await tester.pump();
      expect(find.bySemanticsLabel('Agregar foto de referencia'), findsOneWidget);

      await tester.enterText(_campo, 'Grabar la fecha 14/02/2027');
      await tester.pump();
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();
      expect(servicio.subidas, isEmpty);
      expect(servicio.enviadas.single.imagen, isNull);
    });

    testWidgets('Si el backend la rechaza muestra su mensaje y se queda en el formulario', (tester) async {
      final servicio = _PersonalizacionFalsa(error: const PersonalizacionException('Este producto no admite personalización'));
      await _abrir(tester, servicio, const SolicitarPersonalizacionScreen(producto: _anillo));

      await tester.enterText(_campo, 'Grabar las iniciales D & L');
      await tester.pump();
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();

      expect(find.text('Este producto no admite personalización'), findsOneWidget);
      expect(find.text('¡Solicitud enviada!'), findsNothing);
    });

    testWidgets('Sin sesión invita a iniciarla', (tester) async {
      final servicio = _PersonalizacionFalsa(error: const PersonalizacionException('Inicia sesión para solicitar una personalización.', sinSesion: true));
      await _abrir(tester, servicio, const SolicitarPersonalizacionScreen(producto: _anillo));

      await tester.enterText(_campo, 'Grabar las iniciales D & L');
      await tester.pump();
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla de login'), findsOneWidget);
    });
  });
}

// PNG de 1×1 píxel para la foto de referencia de prueba.
const _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, //
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
