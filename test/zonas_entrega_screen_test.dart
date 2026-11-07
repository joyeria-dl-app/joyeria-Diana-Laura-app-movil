// TIPO: widget
// ALCANCE: HU-16 · pantalla de zonas de entrega (#59): zonas, envío, recoger en tienda, WhatsApp, Cómo llegar y estados
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/zonas_entrega_screen_test.dart
// DATOS: servicio de zonas simulado en memoria (sin red); zonas y datos reales de la tienda

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/zona_entrega.dart';
import 'package:joyeria_diana_laura/screens/zonas_entrega_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/zonas_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

const _zonas = [
  ZonaEntrega(id: 1, nombre: 'Huejutla'),
  ZonaEntrega(id: 2, nombre: 'San Felipe', orden: 1),
  ZonaEntrega(id: 3, nombre: 'Jaltocan', orden: 2),
  ZonaEntrega(id: 4, nombre: 'Tampico', orden: 3),
  ZonaEntrega(id: 5, nombre: 'Tehuetlan', orden: 4),
];

const _completa = InfoEntregas(
  zonas: _zonas,
  direccion: 'Calle Lázaro Cárdenas S/N, Col. El Zapote, C.P. 43000, Huejutla de Reyes, Hidalgo',
  horario: 'Lunes a domingo: 9:00 a.m. – 11:00 p.m.',
  whatsapp: '527713321421',
);

class _ZonasFalso extends ZonasService {
  _ZonasFalso({this.info = _completa, this.error}) : super(api: ApiClient());
  InfoEntregas info;
  ZonasException? error;
  int consultas = 0;

  @override
  Future<InfoEntregas> entregas() async {
    consultas++;
    if (error != null) throw error!;
    return info;
  }
}

late List<Uri> _abiertos;

Future<void> _abrir(WidgetTester tester, ZonasService servicio) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  _abiertos = [];
  abrirEnlaceZonas = (uri) async {
    _abiertos.add(uri);
    return true;
  };
  await tester.pumpWidget(
    Provider<ZonasService>.value(
      value: servicio,
      child: MaterialApp(theme: AppTheme.oscuro(), home: const ZonasEntregaScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Muestra las zonas en el orden de la tienda y marca dónde está la tienda', (tester) async {
    await _abrir(tester, _ZonasFalso());

    expect(find.text('Zonas de entrega'), findsOneWidget);
    final y = [for (final z in _zonas) tester.getTopLeft(find.text(z.nombre)).dy];
    expect(y, orderedEquals([...y]..sort()));
    expect(find.text('Aquí está la tienda'), findsOneWidget);
    expect(find.text('Envío por terceros'), findsOneWidget);
  });

  testWidgets('Más abajo muestra la tienda con su dirección y horario', (tester) async {
    await _abrir(tester, _ZonasFalso());
    await tester.scrollUntilVisible(find.text('Cómo llegar'), 200);

    expect(find.text('También puedes recoger en tienda'), findsOneWidget);
    expect(find.textContaining('Calle Lázaro Cárdenas'), findsOneWidget);
    expect(find.text('Lunes a domingo: 9:00 a.m. – 11:00 p.m.'), findsOneWidget);
  });

  testWidgets('Preguntar por mi zona abre WhatsApp con el mensaje del sitio web', (tester) async {
    await _abrir(tester, _ZonasFalso());
    await tester.tap(find.byKey(const Key('zonas_preguntar')));
    await tester.pump();

    expect(_abiertos.single.toString(), 'https://wa.me/527713321421?text=Hola%2C+%C2%BFhacen+entregas+en+mi+zona%3F');
  });

  testWidgets('Cómo llegar abre el mapa con la dirección de la tienda', (tester) async {
    await _abrir(tester, _ZonasFalso());
    await tester.scrollUntilVisible(find.text('Cómo llegar'), 200);
    await tester.tap(find.text('Cómo llegar'));
    await tester.pump();

    expect(_abiertos.single.host, 'www.google.com');
    expect(_abiertos.single.queryParameters['destination'], _completa.direccion);
  });

  testWidgets('Si la tienda no tiene zonas activas lo dice y deja la tienda para recoger', (tester) async {
    await _abrir(
      tester,
      _ZonasFalso(
        info: InfoEntregas(zonas: const [], direccion: _completa.direccion, whatsapp: _completa.whatsapp),
      ),
    );

    expect(find.text('Por ahora no hay zonas de entrega'), findsOneWidget);
    expect(find.text('Aquí está la tienda'), findsNothing);
    expect(find.byKey(const Key('zonas_preguntar')), findsOneWidget);
  });

  testWidgets('Sin datos de la tienda no muestra la sección para recoger ni el botón de WhatsApp', (tester) async {
    await _abrir(tester, _ZonasFalso(info: const InfoEntregas(zonas: _zonas)));

    expect(find.text('Huejutla'), findsOneWidget);
    expect(find.text('También puedes recoger en tienda'), findsNothing);
    expect(find.byKey(const Key('zonas_preguntar')), findsNothing);
  });

  testWidgets('Sin conexión deja reintentar y entonces muestra las zonas', (tester) async {
    final servicio = _ZonasFalso(error: const ZonasException('sin red'));
    await _abrir(tester, servicio);
    expect(find.text('Sin conexión'), findsOneWidget);

    servicio.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Huejutla'), findsOneWidget);
    expect(servicio.consultas, 2);
  });
}
