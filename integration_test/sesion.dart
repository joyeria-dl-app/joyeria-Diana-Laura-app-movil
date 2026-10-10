import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalogo_test.dart' show esperar;

// Inicio de sesión compartido por las pruebas del emulador (#189).
// Antes cada prueba tocaba "Iniciar sesión" en cuanto aparecía el formulario; si la
// pantalla seguía en animación o el teclado tapaba el botón, el toque no entraba y la
// prueba se quedaba esperando "Ver catálogo". Aquí se espera la animación, se cierra el
// teclado, se hace visible el botón y se reintenta si el toque no entró.
Future<void> iniciarSesion(WidgetTester tester, String correo, String contrasena) async {
  await esperar(tester, find.byType(FilledButton));
  if (find.text('Ver catálogo').evaluate().isNotEmpty) return;

  await tester.tap(find.text('Iniciar sesión').first);
  await esperar(tester, find.byKey(const Key('login_email')));
  await _calmar(tester);

  await tester.enterText(find.descendant(of: find.byKey(const Key('login_email')), matching: find.byType(EditableText)), correo);
  await tester.enterText(find.descendant(of: find.byKey(const Key('login_password')), matching: find.byType(EditableText)), contrasena);

  for (var intento = 1; intento <= 3; intento++) {
    FocusManager.instance.primaryFocus?.unfocus();
    await _calmar(tester);
    final boton = find.text('Iniciar sesión').last;
    if (boton.evaluate().isNotEmpty) {
      await tester.ensureVisible(boton);
      await _calmar(tester);
      await tester.tap(boton, warnIfMissed: false);
    }
    if (await _aparece(tester, find.text('Ver catálogo'), const Duration(seconds: 45))) return;
    debugPrint('SESION intento $intento sin entrar; se reintenta');
  }
  await esperar(tester, find.text('Ver catálogo'));
}

// Deja pasar animaciones y el cierre del teclado sin pumpAndSettle (los destellos del fondo no terminan nunca).
Future<void> _calmar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<bool> _aparece(WidgetTester tester, Finder buscado, Duration limite) async {
  final fin = DateTime.now().add(limite);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (buscado.evaluate().isNotEmpty) return true;
  }
  return false;
}
