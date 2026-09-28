import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/auth_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

class _AuthServiceFalso extends AuthService {
  _AuthServiceFalso(SessionStorage storage) : super(api: ApiClient(), storage: storage, apiKey: 'x');

  String? tipoRecibido;

  @override
  Future<List<String>> preguntasSecretas() async => ['¿Mascota?', '¿Ciudad?'];

  @override
  Future<void> registrarse({
    required String nombre,
    required String email,
    required String password,
    required String tipoPregunta,
    String? preguntaPersonalizada,
    required String respuesta,
  }) async {
    tipoRecibido = tipoPregunta;
  }
}

Future<_AuthServiceFalso> _abrirRegistro(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final storage = MemorySessionStorage();
  final servicio = _AuthServiceFalso(storage);
  await tester.pumpWidget(JoyeriaApp(storage: storage, authService: servicio));
  await tester.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
  await tester.pumpAndSettle();
  return servicio;
}

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _llenarDatos(WidgetTester tester) async {
  await tester.enterText(find.descendant(of: find.byKey(const Key('registro_nombre')), matching: find.byType(TextFormField)), 'Ana Martínez');
  await tester.enterText(find.descendant(of: find.byKey(const Key('registro_email')), matching: find.byType(TextFormField)), 'ana@correo.com');
  await tester.enterText(find.descendant(of: find.byKey(const Key('registro_password')), matching: find.byType(TextFormField)), 'Clave1234');
  await tester.enterText(find.descendant(of: find.byKey(const Key('registro_confirmacion')), matching: find.byType(TextFormField)), 'Clave1234');
  await tester.pump();
}

void main() {
  testWidgets('Muestra el diseño del boceto y valida antes de continuar', (tester) async {
    await _abrirRegistro(tester);

    expect(find.text('Paso 1 de 2'), findsOneWidget);
    await _tocar(tester, find.text('Continuar'));

    expect(find.text('Ingresa tu nombre completo'), findsOneWidget);
    expect(find.text('Debes aceptar el aviso de privacidad'), findsOneWidget);
    expect(find.text('Paso 1 de 2'), findsOneWidget);
  });

  testWidgets('Las reglas de la contraseña se marcan mientras se escribe', (tester) async {
    await _abrirRegistro(tester);

    await tester.enterText(find.descendant(of: find.byKey(const Key('registro_password')), matching: find.byType(TextFormField)), 'Clave');
    await tester.pump();

    final iconoMayuscula = tester.widget<Icon>(
      find.descendant(of: find.ancestor(of: find.text('Mayúscula'), matching: find.byType(Row)).first, matching: find.byType(Icon)),
    );
    expect(iconoMayuscula.icon, Icons.check_rounded);
  });

  testWidgets('Con datos válidos pasa a la pregunta secreta y crea la cuenta', (tester) async {
    final servicio = await _abrirRegistro(tester);

    await _llenarDatos(tester);
    await _tocar(tester, find.byKey(const Key('registro_aviso')));
    await _tocar(tester, find.text('Continuar'));

    expect(find.text('Paso 2 de 2'), findsOneWidget);
    await _tocar(tester, find.byKey(const Key('pregunta_1')));
    await tester.enterText(find.descendant(of: find.byKey(const Key('registro_respuesta')), matching: find.byType(TextFormField)), 'Tula');
    await _tocar(tester, find.text('Crear cuenta'));

    expect(servicio.tipoRecibido, '1');
    expect(find.text('Revisa tu correo'), findsOneWidget);
  });
}
