import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

// Pruebas de integración y aceptación: la app real contra el backend de Render.
// Se ejecutan en un emulador Android (pipeline pruebas-integracion.yml).

// Render apaga el servicio sin uso; la primera respuesta puede tardar.
Future<void> esperar(WidgetTester tester, Finder buscado, {Duration limite = const Duration(seconds: 90)}) async {
  final fin = DateTime.now().add(limite);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (buscado.evaluate().isNotEmpty) return;
    // Si el servidor aún despertaba y la app mostró "Sin conexión", se reintenta como lo haría el usuario.
    final reintentar = find.text('Reintentar');
    if (reintentar.evaluate().isNotEmpty) {
      await tester.tap(reintentar.first);
      await tester.pump(const Duration(seconds: 3));
    }
  }
  fail('No apareció $buscado en ${limite.inSeconds} s');
}

// Despierta el servidor antes de abrir la app (puede tardar más de un minuto).
Future<void> despertarServidor() async {
  final dio = Dio(BaseOptions(baseUrl: apiBaseUrl, receiveTimeout: const Duration(seconds: 150)));
  for (var intento = 0; intento < 3; intento++) {
    try {
      await dio.get<dynamic>('/products/categorias');
      return;
    } on DioException {
      // Sigue arrancando; se vuelve a intentar.
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('HU-07 y HU-08: explorar el catálogo, filtrar y abrir el detalle de una pieza', (tester) async {
    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await esperar(tester, find.text('Explorar sin cuenta'));
    await tester.tap(find.text('Explorar sin cuenta'));

    // Catálogo con piezas reales.
    await esperar(tester, find.textContaining('piezas'));
    expect(find.text('Nuestras joyas'), findsOneWidget);

    // Filtro por categoría.
    await esperar(tester, find.text('Anillos'));
    await tester.tap(find.text('Anillos').first);
    await esperar(tester, find.text('Anillos').at(1));

    // Detalle de la primera pieza.
    await esperar(tester, find.textContaining('\$'));
    await tester.tap(find.textContaining('\$').first);
    await esperar(tester, find.text('Precio'));
    expect(find.textContaining('MXN', findRichText: true), findsWidgets);

    // Regresar al catálogo.
    await tester.tap(find.bySemanticsLabel('Regresar'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomScrollView), findsOneWidget);
  });
}
