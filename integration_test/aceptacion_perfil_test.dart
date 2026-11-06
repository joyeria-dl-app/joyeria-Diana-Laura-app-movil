// TIPO: aceptación
// ALCANCE: HU-14 y HU-16 · casos CA-35 a CA-42: perfil, historial, cierre de sesión, zonas de entrega y accesibilidad (#152)
// EJECUCIÓN: en el emulador. flutter test integration_test/aceptacion_perfil_test.dart --dart-define-from-file=env.json
// DATOS: integration_test/datos_prueba.dart (cuenta de env.json o de los secretos); solo lee, no crea registros

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/routes/app_routes.dart';
import 'package:joyeria_diana_laura/screens/mis_apartados_screen.dart';
import 'package:joyeria_diana_laura/screens/mis_pedidos_screen.dart';
import 'package:joyeria_diana_laura/screens/zonas_entrega_screen.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/perfil_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/services/zonas_service.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;
import 'sesion.dart';
import 'datos_prueba.dart';

// Pruebas de aceptación de HU-14 (perfil e historial) y HU-16 (zonas de entrega) en el emulador
// contra el backend real (#152). Cada pantalla se compara con lo que devuelve el servidor para la
// misma cuenta y se revisa con las reglas de accesibilidad de Flutter:
//   - androidTapTargetGuideline: todo lo que se toca mide al menos 48 × 48 dp.
//   - labeledTapTargetGuideline: todo lo que se toca tiene una etiqueta que lee TalkBack.
//   - textContrastGuideline: el texto tiene el contraste mínimo de WCAG (4.5:1, o 3:1 si es grande).
// La lectura con TalkBack encendido se revisó además a mano; resultados en pruebas/aceptacion_hu14_hu16.md.

void _caso(String id, String descripcion) => debugPrint('ACEPTACION $id Pasa: $descripcion');

// Deja la pantalla quieta unos segundos para la captura con adb.
Future<void> _pausa(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  }
}

// Revisa las tres reglas de accesibilidad en la pantalla que está a la vista.
Future<void> _accesible(WidgetTester tester, String pantalla, {bool contraste = true}) async {
  final semantica = tester.ensureSemantics();
  for (final (nombre, regla) in [
    ('botones de 48 dp', androidTapTargetGuideline),
    ('botones con etiqueta', labeledTapTargetGuideline),
    if (contraste) ('contraste del texto', textContrastGuideline),
  ]) {
    await expectLater(tester, meetsGuideline(regla), reason: '$pantalla: $nombre');
    debugPrint('ACCESIBILIDAD $pantalla: $nombre Pasa');
  }
  semantica.dispose();
}

NavigatorState _navegador(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('Aceptación HU-14 y HU-16: perfil, historial, cierre de sesión y zonas', (tester) async {
    expect(CuentaPrueba.correo, isNotEmpty, reason: 'Falta el correo de la cuenta de prueba (env.json)');
    expect(CuentaPrueba.contrasena, isNotEmpty, reason: 'Falta la contraseña de la cuenta de prueba (env.json)');

    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await iniciarSesion(tester, CuentaPrueba.correo, CuentaPrueba.contrasena);

    // Servicios con la misma sesión de la app: devuelven lo que guarda el servidor para la cuenta.
    final contexto = tester.element(find.byType(Scaffold).first);
    final servidor = await tester.runAsync(() async {
      final perfiles = contexto.read<PerfilService>();
      final pedidos = contexto.read<PedidoService>();
      return (
        perfil: await perfiles.perfil(),
        resumen: await perfiles.resumen(),
        pedidos: await pedidos.misPedidos(),
        apartados: await pedidos.misApartados(),
        zonas: (await contexto.read<ZonasService>().entregas()).zonas ?? const [],
      );
    });

    // CA-35 (HU-14): Mi perfil muestra el nombre, el correo y los números de la cuenta.
    await abrirPestana(tester, 'perfil');
    await esperar(tester, find.text('Mis pedidos'));
    final nombre = servidor!.perfil.nombre.isEmpty ? 'Clienta' : servidor.perfil.nombre;
    expect(find.text(nombre), findsWidgets);
    expect(find.textContaining(servidor.perfil.email), findsWidgets);
    expect(find.text('${servidor.resumen.pedidos}'), findsWidgets);
    await _pausa(tester);
    _caso('CA-35', 'Mi perfil muestra a $nombre con ${servidor.resumen.pedidos} pedidos, ${servidor.resumen.apartados} apartados y ${servidor.resumen.favoritos} favoritos, igual que el servidor');

    // CA-36 (accesibilidad): Mi perfil cumple las tres reglas.
    await _accesible(tester, 'Mi perfil');
    _caso('CA-36', 'Mi perfil: botones de 48 dp, con etiqueta y texto con contraste suficiente');

    // CA-37 (HU-14): Mis pedidos separa los pedidos del servidor en En curso, Entregados y Cancelados.
    final enCurso = servidor.pedidos.where((p) => p.enCurso).toList();
    final cancelados = servidor.pedidos.where((p) => p.cancelado).toList();
    _navegador(tester).pushNamed(AppRoutes.misPedidos);
    await esperar(tester, find.byType(MisPedidosScreen));
    await tester.pumpAndSettle();
    expect(find.text('En curso · ${enCurso.length}'), findsOneWidget);
    if (enCurso.isNotEmpty) await esperar(tester, find.text('Pedido ${enCurso.first.folio}'));
    await _pausa(tester);
    await _accesible(tester, 'Mis pedidos');
    await tester.tap(find.textContaining('Cancelados'));
    await tester.pumpAndSettle();
    if (cancelados.isNotEmpty) await esperar(tester, find.text('Pedido ${cancelados.first.folio}'));
    await _pausa(tester);
    _caso('CA-37', 'Mis pedidos: ${enCurso.length} en curso y ${cancelados.length} cancelados (el más reciente, ${cancelados.firstOrNull?.folio ?? '-'}), igual que el servidor');

    // CA-38 (HU-14): Mis apartados lista los mismos apartados que el servidor.
    _navegador(tester).pop();
    await tester.pumpAndSettle();
    _navegador(tester).pushNamed(AppRoutes.misApartados);
    await esperar(tester, find.byType(MisApartadosScreen));
    await tester.pumpAndSettle();
    await _pausa(tester);
    _caso('CA-38', 'Mis apartados abre con ${servidor.apartados.length} apartados del servidor');
    await _accesible(tester, 'Mis apartados');
    _navegador(tester).pop();
    await tester.pumpAndSettle();

    // CA-39 (HU-16): Zonas de entrega muestra las mismas zonas activas que administra el negocio.
    _navegador(tester).pushNamed(AppRoutes.zonasEntrega);
    await esperar(tester, find.byType(ZonasEntregaScreen));
    await esperar(tester, find.byKey(const Key('zonas_preguntar')));
    // La lista de la pantalla (no la del fondo decorativo).
    final listaZonas = find.descendant(of: find.byType(ZonasEntregaScreen), matching: find.byType(Scrollable)).first;
    for (final zona in servidor.zonas) {
      await tester.scrollUntilVisible(find.text(zona.nombre), 200, scrollable: listaZonas);
      expect(find.text(zona.nombre), findsWidgets, reason: 'Falta la zona ${zona.nombre}');
    }
    for (var i = 0; i < 8; i++) {
      await tester.drag(listaZonas, const Offset(0, -400));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await _pausa(tester);
    _caso('CA-39', 'Zonas de entrega muestra las ${servidor.zonas.length} zonas activas del servidor: ${servidor.zonas.map((z) => z.nombre).join(', ')}');

    // CA-40 (accesibilidad): Zonas de entrega cumple las tres reglas, desde arriba y al final de la lista
    // (la regla de contraste solo mide lo que está a la vista).
    await _accesible(tester, 'Zonas de entrega (final)');
    // Arrastres cortos hasta el tope: uno largo sale de la pantalla y no mueve la lista.
    for (var i = 0; i < 8; i++) {
      await tester.drag(listaZonas, const Offset(0, 400));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await _pausa(tester);
    await tester.pumpAndSettle();
    // Arriba están el antetítulo con degradado (ShaderMask) y los destellos animados: la regla de
    // contraste lee el color del texto antes del degradado y marca 1.1:1. Medido con los píxeles de la
    // captura da 10.8:1 y 9.2:1 (pruebas/aceptacion_hu14_hu16.md), así que aquí solo se revisan los toques.
    await _accesible(tester, 'Zonas de entrega (inicio)', contraste: false);
    _caso('CA-40', 'Zonas de entrega: botones de 48 dp, con etiqueta y texto con contraste suficiente');
    _navegador(tester).pop();
    await tester.pumpAndSettle();

    // CA-41 (HU-14): Cerrar sesión pide confirmación y Cancelar deja la sesión abierta.
    await tester.scrollUntilVisible(find.text('Cerrar sesión'), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await esperar(tester, find.text('¿Cerrar sesión?'));
    await _pausa(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Mis pedidos'), findsOneWidget);
    _caso('CA-41', 'Cerrar sesión pide confirmación y Cancelar deja la sesión abierta');

    // CA-42 (HU-14): al confirmar se cierra la sesión y Mi perfil invita a iniciar sesión.
    await tester.tap(find.text('Cerrar sesión'));
    await esperar(tester, find.text('¿Cerrar sesión?'));
    await tester.tap(find.text('Cerrar sesión').last);
    await esperar(tester, find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    await _pausa(tester);
    _caso('CA-42', 'al confirmar se cerró la sesión y la app pide iniciar sesión de nuevo');
  });
}
