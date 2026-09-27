import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';

void main() {
  testWidgets('La app abre en la pantalla de inicio', (tester) async {
    await tester.pumpWidget(const JoyeriaApp());

    expect(find.text('Joyería Diana Laura'), findsOneWidget);
    expect(find.text('Bienvenido'), findsOneWidget);
  });
}
