import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';

void main() {
  testWidgets('Desde inicio se navega a iniciar sesión y de ahí a registro', (tester) async {
    await tester.pumpWidget(const JoyeriaApp());

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Iniciar sesión'), findsOneWidget);

    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Crear cuenta'), findsOneWidget);
  });

  testWidgets('Desde inicio se navega a crear cuenta', (tester) async {
    await tester.pumpWidget(const JoyeriaApp());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Crear cuenta'), findsOneWidget);
  });
}
