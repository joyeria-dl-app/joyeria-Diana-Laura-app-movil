// TIPO: widget
// ALCANCE: HU-02 · pantalla de registro: validaciones, reglas de contraseña y pregunta secreta
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/register_screen_test.dart
// DATOS: backend simulado en memoria (sin red); datos de registro ficticios

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/auth_service.dart';
import 'package:joyeria_diana_laura/services/legal_service.dart';
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

class _LegalFalso extends LegalService {
  _LegalFalso() : super(api: ApiClient());

  @override
  Future<TextoLegal> obtener(DocumentoLegal doc) async => TextoLegal(titulo: doc.nombre, contenido: 'Texto de ${doc.nombre} para la prueba.');
}

Future<_AuthServiceFalso> _abrirRegistro(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final storage = MemorySessionStorage();
  final servicio = _AuthServiceFalso(storage);
  await tester.pumpWidget(JoyeriaApp(storage: storage, authService: servicio, legalService: _LegalFalso()));
  await tester.tap(find.widgetWithText(OutlinedButton, 'Crear cuenta'));
  await tester.pumpAndSettle();
  return servicio;
}

Future<void> _tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

// Toca el cuadro de la casilla (no el texto, que ahora tiene enlaces a los documentos).
Future<void> _marcarAviso(WidgetTester tester) async {
  final casilla = find.byKey(const Key('registro_aviso'));
  await tester.ensureVisible(casilla);
  await tester.tapAt(tester.getTopLeft(casilla) + const Offset(12, 12));
  await tester.pumpAndSettle();
}

Future<void> _abrirEnlace(WidgetTester tester, String texto) async {
  final etiqueta = find.textContaining('Acepto los', findRichText: true);
  await tester.ensureVisible(etiqueta);
  final raiz = tester.widget<RichText>(etiqueta).text;
  TapGestureRecognizer? enlace;
  raiz.visitChildren((span) {
    if (span is TextSpan && span.text == texto) enlace = span.recognizer as TapGestureRecognizer?;
    return enlace == null;
  });
  enlace!.onTap!();
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
    expect(find.text('Debes aceptar los términos y el aviso de privacidad'), findsOneWidget);
    expect(find.text('Paso 1 de 2'), findsOneWidget);
  });

  testWidgets('Las reglas de la contraseña se marcan mientras se escribe', (tester) async {
    await _abrirRegistro(tester);

    await tester.enterText(find.descendant(of: find.byKey(const Key('registro_password')), matching: find.byType(TextFormField)), 'Clave');
    await tester.pump();

    final iconoMayuscula = tester.widget<Icon>(
      find.descendant(
        of: find.ancestor(of: find.text('Mayúscula'), matching: find.byType(Row)).first,
        matching: find.byType(Icon),
      ),
    );
    expect(iconoMayuscula.icon, Icons.check_rounded);
  });

  testWidgets('Confirmar contraseña tiene su botón para mostrarla (#306)', (tester) async {
    await _abrirRegistro(tester);

    final campo = find.descendant(of: find.byKey(const Key('registro_confirmacion')), matching: find.byType(EditableText));
    expect(tester.widget<EditableText>(campo).obscureText, isTrue);

    await _tocar(tester, find.byKey(const Key('registro_ver_confirmacion')));
    expect(tester.widget<EditableText>(campo).obscureText, isFalse);

    await _tocar(tester, find.byKey(const Key('registro_ver_confirmacion')));
    expect(tester.widget<EditableText>(campo).obscureText, isTrue);
  });

  testWidgets('Los términos y el aviso se leen en una hoja sin perder lo escrito (#321)', (tester) async {
    await _abrirRegistro(tester);
    await tester.enterText(find.descendant(of: find.byKey(const Key('registro_nombre')), matching: find.byType(TextFormField)), 'Ana Martínez');

    expect(find.textContaining('Acepto los términos y condiciones y el aviso de privacidad', findRichText: true), findsOneWidget);
    for (final doc in DocumentoLegal.values) {
      await _abrirEnlace(tester, doc == DocumentoLegal.terminos ? 'términos y condiciones' : 'aviso de privacidad');
      expect(find.text('Texto de ${doc.nombre} para la prueba.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('legal_cerrar')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Ana Martínez'), findsOneWidget);
  });

  testWidgets('Con datos válidos pasa a la pregunta secreta y crea la cuenta', (tester) async {
    final servicio = await _abrirRegistro(tester);

    await _llenarDatos(tester);
    await _marcarAviso(tester);
    await _tocar(tester, find.text('Continuar'));

    expect(find.text('Paso 2 de 2'), findsOneWidget);
    await _tocar(tester, find.byKey(const Key('pregunta_1')));
    await tester.enterText(find.descendant(of: find.byKey(const Key('registro_respuesta')), matching: find.byType(TextFormField)), 'Tula');
    await _tocar(tester, find.text('Crear cuenta'));

    expect(servicio.tipoRecibido, '1');
    expect(find.text('Revisa tu correo'), findsOneWidget);
  });
}
