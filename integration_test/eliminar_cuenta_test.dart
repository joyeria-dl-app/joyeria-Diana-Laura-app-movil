// TIPO: aceptación
// ALCANCE: #273 (ARCO, cancelación) · casos CA-43 a CA-46: eliminar mi cuenta desde Mi perfil
// EJECUCIÓN: A MANO, en el emulador y con una cuenta creada solo para esta prueba (se elimina de verdad).
//   flutter test integration_test/eliminar_cuenta_test.dart --dart-define-from-file=env.json
//     --dart-define=ELIMINAR_CORREO=... --dart-define=ELIMINAR_CONTRASENA=...
// DATOS: la cuenta la crea Backend/_cuenta273.js ya verificada; después ese script revisa la base

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;
import 'sesion.dart';

const _correo = String.fromEnvironment('ELIMINAR_CORREO');
const _contrasena = String.fromEnvironment('ELIMINAR_CONTRASENA');

// Deja la pantalla quieta para la captura con adb.
Future<void> _caso(WidgetTester tester, String id, String descripcion) async {
  debugPrint('ACEPTACION $id Pasa: $descripcion');
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(despertarServidor);

  testWidgets('Aceptación #273: la clienta elimina su cuenta y ya no puede entrar', (tester) async {
    expect(_correo, isNotEmpty, reason: 'Falta ELIMINAR_CORREO (cuenta creada solo para esta prueba)');

    final storage = SecureSessionStorage();
    await tester.pumpWidget(JoyeriaApp(storage: storage));
    await iniciarSesion(tester, _correo, _contrasena);

    // CA-43: con sesión y un favorito guardado (un dato personal que debe borrarse).
    final contexto = tester.element(find.byType(Scaffold).first);
    final pieza = await tester.runAsync(() async {
      final pieza = (await contexto.read<ProductoService>().productos()).first;
      await contexto.read<FavoritoService>().alternar(pieza.id);
      return pieza;
    });
    await abrirPestana(tester, 'perfil');
    await esperar(tester, find.text('Mis pedidos'));
    final lista = find.ancestor(of: find.text('Mis pedidos'), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('perfil_eliminar_cuenta')), 300, scrollable: lista);
    await tester.pump(const Duration(milliseconds: 300));
    await _caso(tester, 'CA-43', 'Mi perfil muestra "Eliminar mi cuenta"; la cuenta tiene 1 favorito (${pieza!.nombre})');

    // CA-44: la confirmación explica qué se borra y qué se conserva.
    await tester.tap(find.byKey(const Key('perfil_eliminar_cuenta')));
    await esperar(tester, find.text('¿Eliminar tu cuenta?'));
    await _caso(tester, 'CA-44', 'la confirmación explica que se borran los datos y se conservan las compras sin nombre');

    // CA-45: al confirmar se elimina, se cierra la sesión y se vuelve al inicio.
    await tester.tap(find.byKey(const Key('eliminar_cuenta_confirmar')));
    await esperar(tester, find.text('Tu cuenta se eliminó'), limite: const Duration(seconds: 60));
    expect(await tester.runAsync(storage.leerToken), isNull);
    await _caso(tester, 'CA-45', 'la cuenta se eliminó, el teléfono ya no guarda la sesión y la app volvió al inicio');

    // CA-46: con el mismo correo y contraseña ya no puede iniciar sesión.
    await esperar(tester, find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión').first);
    await esperar(tester, find.byKey(const Key('login_email')));
    await tester.enterText(find.descendant(of: find.byKey(const Key('login_email')), matching: find.byType(EditableText)), _correo);
    await tester.enterText(find.descendant(of: find.byKey(const Key('login_password')), matching: find.byType(EditableText)), _contrasena);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 500));
    final entrar = find.text('Iniciar sesión').last;
    await tester.ensureVisible(entrar);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(entrar);
    await esperar(tester, find.byIcon(Icons.error_rounded), limite: const Duration(seconds: 60));
    expect(find.byKey(inicioConSesion), findsNothing);
    await _caso(tester, 'CA-46', 'con el mismo correo y contraseña ya no puede iniciar sesión');
  });
}
