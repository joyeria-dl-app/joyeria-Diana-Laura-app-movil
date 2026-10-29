// TIPO: apoyo (no es prueba)
// ALCANCE: inicio de sesión que comparten las pruebas del emulador (#189)
// EJECUCIÓN: lo usan los archivos de integration_test/
// DATOS: la cuenta que le pasa cada prueba

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalogo_test.dart' show esperar;

// Inicio de sesión compartido por las pruebas del emulador (#189).
// Antes cada prueba tocaba "Iniciar sesión" en cuanto aparecía el formulario; si la
// pantalla seguía en animación o el teclado tapaba el botón, el toque no entraba y la
// prueba se quedaba esperando el Inicio con sesión. Aquí se espera la animación, se cierra el
// teclado, se hace visible el botón y se reintenta si el toque no entró.
Future<void> iniciarSesion(WidgetTester tester, String correo, String contrasena) async {
  // Sin sesión el Inicio invita a entrar; con sesión saluda (#244).
  await esperar(tester, find.byWidgetPredicate((w) => w.key == inicioConSesion || (w is Text && w.data == 'Iniciar sesión')));
  if (find.byKey(inicioConSesion).evaluate().isNotEmpty) return;

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
    if (await _aparece(tester, find.byKey(inicioConSesion), const Duration(seconds: 45))) return;
    debugPrint('SESION intento $intento sin entrar; se reintenta');
  }
  await esperar(tester, find.byKey(inicioConSesion));
}

// Saludo del Inicio cuando hay sesión.
const inicioConSesion = Key('inicio_saludo');

// Abre una pestaña de la barra inferior: inicio, catalogo, carrito, favoritos o perfil.
Future<void> abrirPestana(WidgetTester tester, String pestana) async {
  // Cada pantalla abierta tiene su barra; se toca la de la pantalla de arriba (la última).
  await esperar(tester, find.byKey(Key('nav_$pestana')));
  await tester.tap(find.byKey(Key('nav_$pestana')).last);
}

// Desde #244 Cerrar sesión está en Mi perfil: se abre la pestaña, se confirma y se vuelve a la bienvenida.
Future<void> cerrarSesionDesdePerfil(WidgetTester tester) async {
  await abrirPestana(tester, 'perfil');
  // Mi perfil es una lista que construye sus renglones al desplazarse: se baja hasta Cerrar sesión.
  await esperar(tester, find.text('Mis pedidos'));
  await tester.scrollUntilVisible(
    find.text('Cerrar sesión'),
    300,
    scrollable: find.ancestor(of: find.text('Mis pedidos'), matching: find.byType(Scrollable)).first,
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('Cerrar sesión'));
  // Desde #219 la app pide confirmar antes de cerrar la sesión.
  await esperar(tester, find.widgetWithText(TextButton, 'Cerrar sesión'));
  await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
  await esperar(tester, find.text('Explorar sin cuenta'));
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
