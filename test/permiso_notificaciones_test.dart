// TIPO: widget
// ALCANCE: #276 · diálogo que explica el aviso de notificaciones antes del permiso del sistema
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR. flutter test test/permiso_notificaciones_test.dart
// DATOS: ninguno (solo la interfaz)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/theme/app_theme.dart';
import 'package:joyeria_diana_laura/utils/explicar_permiso.dart';

void main() {
  Future<bool?> abrir(WidgetTester tester, String boton) async {
    final navegador = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navegador, home: const SizedBox()),
    );
    bool? resultado;
    explicarPermisoNotificaciones(navegador).then((v) => resultado = v);
    await tester.pumpAndSettle();

    expect(find.text('¿Te avisamos de tus pedidos?'), findsOneWidget);
    expect(
      find.textContaining('cuando tu pedido cambie de estado'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(Key(boton)));
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('"Permitir" devuelve true', (tester) async {
    expect(await abrir(tester, 'permiso_permitir'), isTrue);
  });

  testWidgets('"Ahora no" devuelve false y cierra el diálogo', (tester) async {
    expect(await abrir(tester, 'permiso_ahora_no'), isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Botones de 48 dp y con texto legible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.desde(AppColors.paleta),
        home: const Scaffold(body: DialogoPermisoNotificaciones()),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}
