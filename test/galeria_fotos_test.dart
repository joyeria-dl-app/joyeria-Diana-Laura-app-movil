import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/widgets/galeria_fotos.dart';

// Las fotos se pintan como texto para no depender de la red.
Future<void> _abrir(WidgetTester tester, List<String> imagenes) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 420,
          child: GaleriaFotos(imagenes: imagenes, foto: (url) => Center(child: Text('Foto $url'))),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Con 3 fotos muestra las 3 miniaturas y deslizar cambia la foto', (tester) async {
    await _abrir(tester, ['a', 'b', 'c']);

    expect(find.text('Foto a'), findsOneWidget);
    expect(find.bySemanticsLabel('Foto 3 de 3'), findsOneWidget);
    expect(find.textContaining('+'), findsNothing);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Foto b'), findsOneWidget);
  });

  testWidgets('Con más de 3 fotos muestra 2 miniaturas y "+N"', (tester) async {
    await _abrir(tester, ['a', 'b', 'c', 'd', 'e']);

    expect(find.bySemanticsLabel('Foto 2 de 5'), findsOneWidget);
    expect(find.bySemanticsLabel('Foto 3 de 5'), findsNothing);
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('Tocar una miniatura lleva a esa foto', (tester) async {
    await _abrir(tester, ['a', 'b', 'c']);

    await tester.tap(find.bySemanticsLabel('Foto 3 de 3'));
    await tester.pumpAndSettle();
    expect(find.text('Foto c'), findsOneWidget);
  });

  testWidgets('Tocar "+N" lleva a las fotos ocultas', (tester) async {
    await _abrir(tester, ['a', 'b', 'c', 'd']);

    await tester.tap(find.text('+2'));
    await tester.pumpAndSettle();
    expect(find.text('Foto c'), findsOneWidget);
  });

  testWidgets('Con una sola foto no muestra miniaturas', (tester) async {
    await _abrir(tester, ['a']);

    expect(find.text('Foto a'), findsOneWidget);
    expect(find.bySemanticsLabel('Foto 1 de 1'), findsNothing);
  });
}
