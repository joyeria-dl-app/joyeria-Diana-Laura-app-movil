import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;

// Pruebas de rendimiento: tiempos de la app en el emulador (pipeline pruebas-rendimiento.yml).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(despertarServidor);

  testWidgets('El catálogo carga y se desplaza dentro de los tiempos esperados', (tester) async {
    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await esperar(tester, find.text('Explorar sin cuenta'));

    // Primera visita: despierta el servidor de Render; no cuenta para el tiempo.
    await tester.tap(find.text('Explorar sin cuenta'));
    await esperar(tester, find.textContaining('piezas'));
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tiempo de carga del catálogo con el servidor activo.
    final reloj = Stopwatch()..start();
    await tester.tap(find.text('Explorar sin cuenta'));
    await esperar(tester, find.textContaining('piezas'), limite: const Duration(seconds: 10));
    reloj.stop();

    // Fluidez del scroll: se guarda el resumen de cuadros en el reporte.
    await binding.traceAction(() async {
      for (var i = 0; i < 5; i++) {
        await tester.fling(find.byType(CustomScrollView), const Offset(0, -600), 1500);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'scroll_catalogo');

    binding.reportData = {...?binding.reportData, 'carga_catalogo_ms': reloj.elapsedMilliseconds};
    debugPrint('Carga del catálogo: ${reloj.elapsedMilliseconds} ms');
    expect(reloj.elapsedMilliseconds, lessThan(2000), reason: 'El catálogo debe cargar en menos de 2 s');
  });
}
