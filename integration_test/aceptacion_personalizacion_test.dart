// TIPO: aceptación
// ALCANCE: HU-13 · casos CA-21 a CA-25: solicitar la personalización y verla en el sistema del negocio
// EJECUCIÓN: A MANO, en el emulador: la tienda revisa y rechaza la solicitud. flutter test integration_test/aceptacion_personalizacion_test.dart --dart-define-from-file=env.json
// DATOS: integration_test/datos_prueba.dart (cuenta de env.json o de los secretos); pieza personalizable de datos_prueba.dart; la solicitud se cierra como rechazada

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/models/personalizacion.dart';
import 'package:joyeria_diana_laura/routes/app_routes.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/screens/solicitar_personalizacion_screen.dart';
import 'package:joyeria_diana_laura/services/personalizacion_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;
import 'sesion.dart';
import 'datos_prueba.dart';

// Pruebas de aceptación de HU-13 en el emulador contra el backend real. La tabla con los
// resultados está en pruebas/aceptacion_hu13.md.
//
// Criterio de aceptación: el cliente envía una solicitud desde la app y aparece en el
// sistema del negocio. La respuesta la da la tienda desde el sitio web, así que la prueba
// avisa con "ACEPTACION PASO" lo que toca hacer y espera hasta 15 minutos:
//   revisar <id>    la solicitud aparece en Personalizaciones del panel del trabajador
//   rechazar <id>   la tienda la rechaza con un motivo (panel o base de datos)
// No corre en los pipelines: crea una solicitud real y necesita a alguien que la responda.

// Deja la pantalla quieta unos segundos para tomar la captura de evidencia con adb.
Future<void> _caso(WidgetTester tester, String id, String descripcion) async {
  debugPrint('ACEPTACION $id Pasa: $descripcion');
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  }
}

void _paso(String paso) => debugPrint('ACEPTACION PASO $paso');

NavigatorState _navegador(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

Finder get _campo => find.descendant(of: find.byKey(const Key('personalizacion_detalle')), matching: find.byType(EditableText));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('Aceptación HU-13: solicitar la personalización de una pieza', (tester) async {
    expect(CuentaPrueba.correo, isNotEmpty, reason: 'Falta PRUEBAS_CORREO');
    expect(CuentaPrueba.contrasena, isNotEmpty, reason: 'Falta PRUEBAS_CONTRASENA');

    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await iniciarSesion(tester, CuentaPrueba.correo, CuentaPrueba.contrasena);

    final servicio = tester.element(find.byType(Scaffold).first).read<PersonalizacionService>();

    Future<T> esperarServidor<T>(Future<T?> Function() leer, String que, {int minutos = 15}) async {
      final fin = DateTime.now().add(Duration(minutes: minutos));
      while (DateTime.now().isBefore(fin)) {
        final valor = await tester.runAsync(leer);
        if (valor != null) return valor;
        await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 5)));
        await tester.pump();
      }
      fail('El servidor no registró: $que');
    }

    // CA-21: la pieza que admite personalización invita a pedirla desde su detalle.
    _navegador(tester).push(MaterialPageRoute<void>(builder: (_) => const DetalleScreen(productoId: PiezasPrueba.personalizable)));
    await esperar(tester, find.text('¿La quieres a tu gusto?'));
    final invitacion = find.bySemanticsLabel('Personalizar esta pieza');
    await tester.ensureVisible(invitacion);
    await tester.pumpAndSettle();
    await _caso(tester, 'CA-21', 'la pieza personalizable muestra "¿La quieres a tu gusto?"');

    await tester.tap(invitacion);
    await esperar(tester, find.byType(SolicitarPersonalizacionScreen));

    // CA-22: con menos de 10 caracteres el formulario no deja enviar.
    final antes = (await tester.runAsync(servicio.misSolicitudes))!.length;
    await tester.enterText(_campo, 'Grabado');
    await tester.pump();
    expect(find.text('Escribe al menos 10 caracteres (7/10).'), findsOneWidget);
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();
    expect((await tester.runAsync(servicio.misSolicitudes))!.length, antes);
    await _caso(tester, 'CA-22', 'con 7 caracteres avisa cuántos faltan y no envía nada');

    // CA-23: la solicitud se envía y el servidor la registra pendiente.
    final detalle = 'Prueba de aceptación #147: grabar las iniciales D & L por dentro (${DateTime.now().millisecondsSinceEpoch})';
    await tester.enterText(_campo, detalle);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar solicitud'));
    await esperar(tester, find.text('¡Solicitud enviada!'));
    final solicitud = await esperarServidor(
      () async => (await servicio.misSolicitudes()).where((s) => s.detalle == detalle).firstOrNull,
      'la solicitud enviada',
      minutos: 1,
    );
    expect(solicitud.estado, EstadoSolicitud.pendiente);
    expect(solicitud.productoId, PiezasPrueba.personalizable);
    await _caso(tester, 'CA-23', 'solicitud ${solicitud.id} enviada; el servidor la registra pendiente');
    _paso('revisar ${solicitud.id}');

    // CA-24: Mis personalizaciones la muestra en revisión.
    await tester.tap(find.text('Volver a la pieza'));
    await tester.pumpAndSettle();
    _navegador(tester).pushNamed(AppRoutes.misPersonalizaciones);
    await esperar(tester, find.text(detalle));
    expect(find.text('En revisión'), findsWidgets);
    await _caso(tester, 'CA-24', 'Mis personalizaciones muestra la solicitud "En revisión"');

    // CA-25: cuando la tienda la rechaza, el cliente ve el motivo.
    _paso('rechazar ${solicitud.id}');
    final rechazada = await esperarServidor(
      () async => (await servicio.misSolicitudes()).where((s) => s.id == solicitud.id && s.estado == EstadoSolicitud.rechazada).firstOrNull,
      'el rechazo de la tienda',
    );
    _navegador(tester).pop();
    await tester.pumpAndSettle();
    _navegador(tester).pushNamed(AppRoutes.misPersonalizaciones);
    await esperar(tester, find.text(detalle));
    expect(find.text('No aprobada'), findsWidgets);
    expect(find.textContaining(rechazada.motivoRechazo!.trim()), findsOneWidget);
    await _caso(tester, 'CA-25', 'la solicitud no aprobada muestra el motivo de la tienda');
  });
}
