import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

void main() {
  testWidgets('Desde inicio se navega a iniciar sesión y de ahí a registro', (tester) async {
    await tester.pumpWidget(JoyeriaApp(storage: MemorySessionStorage()));

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Tu brillo,\nen tu bolsillo.'), findsOneWidget);

    await tester.ensureVisible(find.text('Crea tu cuenta'));
    await tester.tap(find.text('Crea tu cuenta'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Crear cuenta'), findsOneWidget);
  });

  testWidgets('Desde inicio se navega a crear cuenta', (tester) async {
    await tester.pumpWidget(JoyeriaApp(storage: MemorySessionStorage()));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Crear cuenta'), findsOneWidget);
  });
}
