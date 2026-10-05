import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/widgets/tarjeta_producto.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;

// Pruebas de rendimiento (HU-07 y HU-08): tiempos de la app en el emulador contra el backend real
// (pipeline pruebas-rendimiento.yml). Criterios del plan: arranque < 3 s, catálogo < 2 s con el
// servidor activo y scroll sin cuadros perdidos notables.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(despertarServidor);

  void anotar(String clave, Object valor) => debugPrint('RENDIMIENTO $clave: $valor');

  testWidgets('Arranque, catálogo, detalle, scroll y memoria dentro de los límites', (tester) async {
    // Arranque: desde que se monta la app hasta que se ve la primera pantalla.
    final arranque = Stopwatch()..start();
    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await esperar(tester, find.text('Explorar sin cuenta'));
    arranque.stop();
    anotar('arranque_ms', arranque.elapsedMilliseconds);

    // Primera visita: despierta el servidor de Render; no cuenta para el tiempo.
    await tester.tap(find.text('Explorar sin cuenta'));
    await esperar(tester, find.textContaining('piezas'));
    // El catálogo no tiene flecha de regreso propia: se vuelve al inicio como con el botón Atrás del teléfono.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    // Carga del catálogo con el servidor activo.
    final catalogo = Stopwatch()..start();
    await tester.tap(find.text('Explorar sin cuenta'));
    await esperar(tester, find.byType(TarjetaProducto), limite: const Duration(seconds: 10));
    catalogo.stop();
    anotar('carga_catalogo_ms', catalogo.elapsedMilliseconds);

    // Fluidez del scroll: se registran los cuadros que dibuja el teléfono mientras se desliza la lista.
    // Un cuadro se pierde si la app tarda más de 16 ms en construirlo (60 cuadros por segundo). El tiempo de
    // dibujo se reporta aparte: en el emulador depende de la tarjeta gráfica de la computadora, no del código.
    final tiempos = <FrameTiming>[];
    void registrar(List<FrameTiming> lote) => tiempos.addAll(lote);
    SchedulerBinding.instance.addTimingsCallback(registrar);
    for (var i = 0; i < 5; i++) {
      await tester.fling(find.byType(CustomScrollView), const Offset(0, -600), 1500);
      await tester.pumpAndSettle();
    }
    for (var i = 0; i < 5; i++) {
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 600), 1500);
      await tester.pumpAndSettle();
    }
    // Los tiempos llegan en lotes: se da un momento para recibir el último.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    SchedulerBinding.instance.removeTimingsCallback(registrar);
    const presupuesto = Duration(microseconds: 16667);
    final cuadros = tiempos.length;
    final perdidos = tiempos.where((t) => t.buildDuration > presupuesto).length;
    final porcentajePerdidos = cuadros == 0 ? 0.0 : perdidos * 100 / cuadros;
    final lentosAlDibujar = tiempos.where((t) => t.rasterDuration > presupuesto).length;
    final promedioMs = cuadros == 0 ? 0.0 : tiempos.fold<int>(0, (suma, t) => suma + t.buildDuration.inMicroseconds) / cuadros / 1000;
    anotar('scroll_cuadros', cuadros);
    anotar('scroll_cuadros_perdidos', perdidos);
    anotar('scroll_porcentaje_perdidos', porcentajePerdidos.toStringAsFixed(1));
    anotar('scroll_promedio_construccion_ms', promedioMs.toStringAsFixed(2));
    anotar('scroll_cuadros_lentos_al_dibujar', '$lentosAlDibujar (${cuadros == 0 ? 0 : (lentosAlDibujar * 100 / cuadros).toStringAsFixed(1)} %, informativo)');

    // Carga del detalle de una pieza (HU-08).
    final detalle = Stopwatch()..start();
    await tester.tap(find.byType(TarjetaProducto).first);
    await esperar(tester, find.text('Precio'), limite: const Duration(seconds: 10));
    detalle.stop();
    anotar('carga_detalle_ms', detalle.elapsedMilliseconds);
    expect(find.byType(DetalleScreen), findsOneWidget);

    // Memoria usada por la app al terminar el recorrido.
    final memoriaMb = ProcessInfo.currentRss ~/ (1024 * 1024);
    // Informativo: en modo debug la memoria incluye las herramientas de depuración.
    anotar('memoria_mb', '$memoriaMb (informativo)');

    expect(arranque.elapsedMilliseconds, lessThan(3000), reason: 'La app debe arrancar en menos de 3 s');
    expect(catalogo.elapsedMilliseconds, lessThan(2000), reason: 'El catálogo debe cargar en menos de 2 s');
    // El plan no fija un límite para el detalle; se usa 3 s, igual que el arranque, porque depende de la respuesta
    // del servidor de Render y en las corridas locales tomó entre 1.6 y 2.2 s.
    expect(detalle.elapsedMilliseconds, lessThan(3000), reason: 'El detalle debe cargar en menos de 3 s');
    // En modo debug (como corre la prueba) los cuadros son más lentos que en el APK final; se tolera hasta 25 %.
    expect(porcentajePerdidos, lessThan(25), reason: 'El scroll no debe perder cuadros de forma notable');
  });
}
