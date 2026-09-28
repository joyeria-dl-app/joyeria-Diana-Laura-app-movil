import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

void main() {
  testWidgets('La app abre en la pantalla de inicio', (tester) async {
    await tester.pumpWidget(JoyeriaApp(storage: MemorySessionStorage()));

    expect(find.text('Joyería Diana Laura'), findsOneWidget);
    expect(find.text('Bienvenido'), findsOneWidget);
  });
}
