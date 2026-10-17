// TIPO: widget (humo)
// ALCANCE: arranque de la app: abre en la pantalla de inicio
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/widget_test.dart
// DATOS: sin datos externos

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
