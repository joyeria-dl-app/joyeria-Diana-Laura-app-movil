// TIPO: seguridad (widget)
// ALCANCE: HU-19 · teléfonos con root: aviso, sesión sin guardar y pago en línea bloqueado (#99)
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/root_test.dart
// DATOS: detección de root simulada; sin red

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/services/dispositivo_root.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/utils/pago_en_linea.dart';

// HU-19 · Caso agregado al alcance el 11 de octubre de 2026: con root la app avisa, no guarda la
// sesión y no abre Mercado Pago. El servidor sigue siendo quien valida el pago (#98).

void main() {
  tearDown(() {
    dispositivoConRoot = false;
    detectarRoot = () async => false;
  });

  group('Detección', () {
    test('Marca el teléfono con root cuando la detección lo encuentra', () async {
      detectarRoot = () async => true;
      expect(await revisarRoot(), isTrue);
      expect(dispositivoConRoot, isTrue);
    });

    test('Sin root la app sigue igual', () async {
      detectarRoot = () async => false;
      expect(await revisarRoot(), isFalse);
    });

    test('Si la detección falla, se trata como un teléfono normal', () async {
      detectarRoot = () async => throw Exception('sin plugin');
      expect(await revisarRoot(), isFalse);
    });
  });

  group('Con root', () {
    testWidgets('Avisa arriba de la pantalla', (tester) async {
      dispositivoConRoot = true;
      await tester.pumpWidget(JoyeriaApp(storage: MemorySessionStorage()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('aviso_root')), findsOneWidget);
      expect(find.text(avisoRoot), findsOneWidget);
    });

    testWidgets('Sin root no hay aviso', (tester) async {
      await tester.pumpWidget(JoyeriaApp(storage: MemorySessionStorage()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('aviso_root')), findsNothing);
    });

    testWidgets('No abre Mercado Pago ni pide la preferencia', (tester) async {
      dispositivoConRoot = true;
      var pedidas = 0;
      var abiertas = 0;
      abrirEnlacePago = (_) async {
        abiertas++;
        return true;
      };
      late bool abierta;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => abierta = await abrirPagoMercadoPago(context, () async {
                  pedidas++;
                  return const PreferenciaPago(id: 'p', enlace: 'https://www.mercadopago.com.mx');
                }),
                child: const Text('Pagar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pagar'));
      await tester.pump();

      expect(abierta, isFalse);
      expect(pedidas, 0);
      expect(abiertas, 0);
      expect(find.textContaining('no se puede pagar en línea'), findsOneWidget);
    });
  });

  test('Con root la sesión solo vive en memoria (no se escribe en el teléfono)', () {
    final principal = File('lib/main.dart').readAsStringSync();
    expect(principal, contains('conRoot ? MemorySessionStorage() : SecureSessionStorage()'));
  });
}
