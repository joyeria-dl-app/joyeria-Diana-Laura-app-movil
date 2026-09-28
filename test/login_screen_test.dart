import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/models/usuario.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/auth_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

class _AuthServiceFalso extends AuthService {
  _AuthServiceFalso(SessionStorage storage) : super(api: ApiClient(), storage: storage, apiKey: 'x');

  @override
  Future<Usuario> iniciarSesion(String email, String password, {bool recordar = true}) async {
    if (password != 'correcta') throw const AuthException('Correo o contraseña incorrectos. Te queda 1 intento.');
    return const Usuario(email: 'ana@correo.com', nombre: 'Ana', rol: 'cliente');
  }
}

Future<void> _abrirLogin(WidgetTester tester) async {
  final storage = MemorySessionStorage();
  await tester.pumpWidget(JoyeriaApp(storage: storage, authService: _AuthServiceFalso(storage)));
  await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
  await tester.pumpAndSettle();
}

Future<void> _enviar(WidgetTester tester) async {
  final boton = find.text('Iniciar sesión');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Muestra el diseño del boceto y valida el correo', (tester) async {
    await _abrirLogin(tester);

    expect(find.text('JOYERÍA DIANA LAURA'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login_email')), 'correo-sin-arroba');
    await _enviar(tester);

    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('Con contraseña incorrecta muestra el error', (tester) async {
    await _abrirLogin(tester);

    await tester.enterText(find.byKey(const Key('login_email')), 'ana@correo.com');
    await tester.enterText(find.byKey(const Key('login_password')), 'mala');
    await _enviar(tester);

    expect(find.text('Correo o contraseña incorrectos. Te queda 1 intento.'), findsOneWidget);
  });

  testWidgets('Con datos correctos llega al inicio y saluda al usuario', (tester) async {
    await _abrirLogin(tester);

    await tester.enterText(find.byKey(const Key('login_email')), 'ana@correo.com');
    await tester.enterText(find.byKey(const Key('login_password')), 'correcta');
    await _enviar(tester);

    expect(find.text('Hola, Ana'), findsOneWidget);
  });
}
