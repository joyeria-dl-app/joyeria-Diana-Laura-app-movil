// TIPO: integración
// ALCANCE: HU-09, HU-11, HU-12 y HU-13 · casos I-01 a I-06: carrito, pedido, pago con Mercado Pago y personalización en un recorrido
// EJECUCIÓN: A MANO, en el emulador: la tienda confirma el pedido y se paga en Mercado Pago. flutter test integration_test/integracion_compra_test.dart --dart-define-from-file=env.json
// DATOS: integration_test/datos_prueba.dart (cuenta de env.json o de los secretos); comprador de prueba de Mercado Pago; pedido y solicitud reales que se cancelan al terminar

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/models/personalizacion.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/routes/app_routes.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/personalizacion_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/utils/formato.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;
import 'sesion.dart';
import 'datos_prueba.dart';

// Prueba de integración del Sprint 3 (#146): un solo recorrido que une HU-09, HU-11, HU-12 y
// HU-13 en el emulador contra el backend real. En cada paso se compara lo que muestra la app
// con lo que registra el servidor. Resultados en pruebas/integracion_sprint3.md.
//
// La prueba avisa con "INTEGRACION PASO" lo que hace la tienda o el comprador:
//   confirmar <folio>   la tienda confirma el pedido (panel o base de datos)
//   pagar               pagar en Mercado Pago con el comprador de prueba
//   limpiar <folio> <solicitud>  cancelar el pedido y cerrar la solicitud de prueba
// No corre en los pipelines: necesita a la tienda y un pago con la cuenta de prueba.

// Deja la pantalla quieta unos segundos para la captura de evidencia con adb.
Future<void> _caso(WidgetTester tester, String id, String descripcion) async {
  debugPrint('INTEGRACION $id Pasa: $descripcion');
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  }
}

void _paso(String paso) => debugPrint('INTEGRACION PASO $paso');

NavigatorState _navegador(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

Finder get _campoPersonalizacion => find.descendant(of: find.byKey(const Key('personalizacion_detalle')), matching: find.byType(EditableText));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('Integración Sprint 3: carrito, pedido, pago con Mercado Pago y personalización', (tester) async {
    expect(CuentaPrueba.correo, isNotEmpty, reason: 'Falta PRUEBAS_CORREO');
    expect(CuentaPrueba.contrasena, isNotEmpty, reason: 'Falta PRUEBAS_CONTRASENA');

    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await iniciarSesion(tester, CuentaPrueba.correo, CuentaPrueba.contrasena);

    final contexto = tester.element(find.byType(Scaffold).first);
    final pedidos = contexto.read<PedidoService>();
    final carritoServidor = contexto.read<CarritoService>();
    final carrito = contexto.read<CarritoProvider>();
    final personalizacion = contexto.read<PersonalizacionService>();

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

    Future<Pedido?> pedido(String folio, bool Function(Pedido) cumple) async =>
        (await pedidos.misPedidos()).where((p) => p.folio == folio && cumple(p)).firstOrNull;

    // I-01 (HU-09): la pieza más barata de Anillos con existencia llega al carrito con su precio.
    final pieza = (await tester.runAsync(() async {
      final productos = contexto.read<ProductoService>();
      final anillos = (await productos.categorias()).firstWhere((c) => c.nombre == PiezasPrueba.categoriaCompra);
      final lista = (await productos.productos(categoriaId: anillos.id)).where((p) => p.stock >= 2).toList()
        ..sort((a, b) => a.precioFinal.compareTo(b.precioFinal));
      return lista.first;
    }))!;
    await tester.runAsync(() async {
      await carritoServidor.vaciar();
      await carritoServidor.agregar(pieza.id);
      await carrito.cargar();
    });
    _navegador(tester).pushNamed(AppRoutes.carrito);
    await esperar(tester, find.text('Ir a pagar'));
    expect(find.text(pieza.nombre), findsWidgets);
    await _caso(tester, 'I-01', 'el carrito tiene ${pieza.nombre} de ${formatoPrecioCompleto(pieza.precioFinal)}, igual que en el servidor');

    // I-02 (HU-11): el pedido se crea en el servidor y Mis pedidos lo muestra pendiente.
    await tester.tap(find.text('Ir a pagar'));
    await esperar(tester, find.text('Confirmar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mercado Pago'));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await esperar(tester, find.text('¡Pedido enviado!'));
    final folio = (tester.widget<Text>(find.textContaining(RegExp(r'^Pedido DL-'))).data!).replaceFirst('Pedido ', '');
    final creado = await esperarServidor(() => pedido(folio, (p) => p.estado == 'pendiente'), 'el pedido $folio', minutos: 1);
    expect(creado.total, closeTo(pieza.precioFinal, 0.01));
    await tester.tap(find.text('Ver mis pedidos'));
    await esperar(tester, find.text('Pedido $folio'));
    await _caso(tester, 'I-02', 'el pedido $folio de ${formatoPrecioCompleto(creado.total)} quedó pendiente en el servidor y en Mis pedidos');

    // I-03: la tienda lo confirma y el seguimiento ofrece pagar con Mercado Pago.
    _paso('confirmar $folio');
    await esperarServidor(() => pedido(folio, (p) => p.estado == 'confirmado'), 'el pedido $folio confirmado');
    _navegador(tester).pop();
    await tester.pumpAndSettle();
    _navegador(tester).pushNamed(AppRoutes.misPedidos);
    await esperar(tester, find.text('Pedido $folio'));
    await tester.tap(find.text('Pedido $folio'));
    await esperar(tester, find.byType(SeguimientoScreen));
    await esperar(tester, find.text('Paga con Mercado Pago'));
    await _caso(tester, 'I-03', 'la tienda confirmó $folio y el seguimiento ofrece pagar con Mercado Pago');

    // I-04 (HU-12): pago con el comprador de prueba; la app y el servidor lo registran aprobado.
    await tester.tap(find.byTooltip('Pagar con Mercado Pago'));
    _paso('pagar');
    await esperar(tester, find.text('¡Pago recibido!'), limite: TiemposPrueba.pasoManual);
    final pagado = await esperarServidor(() => pedido(folio, (p) => p.pagado), 'el pago de $folio (webhook)');
    await _caso(tester, 'I-04', 'la app muestra "¡Pago recibido!" y el servidor tiene $folio pagado (${formatoPrecioCompleto(pagado.total)})');

    // I-05: el seguimiento del pedido pagado ya no ofrece pagar.
    await tester.tap(find.text('Ver mi pedido'));
    await esperar(tester, find.byType(SeguimientoScreen));
    await tester.pumpAndSettle();
    expect(find.text('Paga con Mercado Pago'), findsNothing);
    await _caso(tester, 'I-05', 'el seguimiento de $folio ya no ofrece pagar');
    _navegador(tester).popUntil((ruta) => ruta.isFirst);
    await tester.pumpAndSettle();

    // I-06 (HU-13): la solicitud de personalización llega al servidor y Mis personalizaciones la muestra en revisión.
    final detalle = 'Prueba de integración #146: grabar las iniciales D & L (${DateTime.now().millisecondsSinceEpoch})';
    _navegador(tester).push(MaterialPageRoute<void>(builder: (_) => const DetalleScreen(productoId: PiezasPrueba.personalizable)));
    await esperar(tester, find.text('¿La quieres a tu gusto?'));
    final invitacion = find.bySemanticsLabel('Personalizar esta pieza');
    await tester.ensureVisible(invitacion);
    await tester.pumpAndSettle();
    await tester.tap(invitacion);
    await esperar(tester, find.byKey(const Key('personalizacion_detalle')));
    await tester.enterText(_campoPersonalizacion, detalle);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar solicitud'));
    await esperar(tester, find.text('¡Solicitud enviada!'));
    final solicitud = await esperarServidor(
      () async => (await personalizacion.misSolicitudes()).where((s) => s.detalle == detalle && s.estado == EstadoSolicitud.pendiente).firstOrNull,
      'la solicitud de personalización',
      minutos: 1,
    );
    await tester.tap(find.text('Volver a la pieza'));
    await tester.pumpAndSettle();
    _navegador(tester).pushNamed(AppRoutes.misPersonalizaciones);
    await esperar(tester, find.text(detalle));
    expect(find.text('En revisión'), findsWidgets);
    await _caso(tester, 'I-06', 'la solicitud ${solicitud.id} quedó pendiente en el servidor y Mis personalizaciones la muestra en revisión');

    _paso('limpiar $folio ${solicitud.id}');
  });
}
