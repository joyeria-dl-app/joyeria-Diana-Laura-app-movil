import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/routes/app_routes.dart';
import 'package:joyeria_diana_laura/screens/mis_apartados_screen.dart';
import 'package:joyeria_diana_laura/screens/mis_pedidos_screen.dart';
import 'package:joyeria_diana_laura/screens/resultado_pago_screen.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/utils/formato.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;
import 'sesion.dart';

// Pruebas de aceptación de HU-12 en el emulador contra el backend real y las cuentas de
// vendedor y comprador de prueba de Mercado Pago (no hay cobros reales). La tabla con los
// resultados está en pruebas/aceptacion_hu12.md.
//
// El pago se hace a mano en la página de Mercado Pago que abre el teléfono, con las
// tarjetas de prueba; por eso la prueba avisa con "ACEPTACION PASO" lo que toca hacer
// y espera hasta 15 minutos a que Mercado Pago regrese a la app:
//   confirmar <folio>   la tienda confirma el pedido (panel o base de datos)
//   pagar rechazado     pagar con la tarjeta de prueba y el titular OTHE
//   pagar aprobado      pagar con el saldo del comprador de prueba (o titular APRO)
// No corre en los pipelines: necesita a alguien que pague. Crea un pedido y un apartado
// reales que después la tienda cancela.
// flutter test integration_test/aceptacion_pago_test.dart --dart-define-from-file=env.json --dart-define=PAGO_MP=true
const _correo = String.fromEnvironment('PRUEBAS_CORREO');
const _contrasena = String.fromEnvironment('PRUEBAS_CONTRASENA');
const _pagoMp = bool.fromEnvironment('PAGO_MP');

void _caso(String id, String descripcion) => debugPrint('ACEPTACION $id Pasa: $descripcion');
void _paso(String paso) => debugPrint('ACEPTACION PASO $paso');

NavigatorState _navegador(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('Aceptación HU-12: pagar con Mercado Pago desde la app', (tester) async {
    expect(_correo, isNotEmpty, reason: 'Falta PRUEBAS_CORREO');
    expect(_contrasena, isNotEmpty, reason: 'Falta PRUEBAS_CONTRASENA');

    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await iniciarSesion(tester, _correo, _contrasena);

    final contexto = tester.element(find.byType(Scaffold).first);
    final pedidosServidor = contexto.read<PedidoService>();
    final carritoServidor = contexto.read<CarritoService>();
    final carrito = contexto.read<CarritoProvider>();

    // Espera a que el servidor cumpla la condición (lo que hace la tienda o el webhook de Mercado Pago).
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
        (await pedidosServidor.misPedidos()).where((p) => p.folio == folio && cumple(p)).firstOrNull;

    // Pieza de prueba: el anillo más barato con existencia.
    final pieza = (await tester.runAsync(() async {
      final productos = contexto.read<ProductoService>();
      final anillos = (await productos.categorias()).firstWhere((c) => c.nombre == 'Anillos');
      final lista = (await productos.productos(categoriaId: anillos.id)).where((p) => p.stock >= 2).toList()
        ..sort((a, b) => a.precioFinal.compareTo(b.precioFinal));
      return lista.first;
    }))!;

    Future<void> llenarCarrito() async {
      await tester.runAsync(() async {
        await carritoServidor.vaciar();
        await carritoServidor.agregar(pieza.id);
        await carrito.cargar();
      });
      _navegador(tester).pushNamed(AppRoutes.carrito);
      await esperar(tester, find.text('Ir a pagar'));
      await tester.tap(find.text('Ir a pagar'));
      await esperar(tester, find.text('Confirmar pedido'));
      await tester.pumpAndSettle();
    }

    Future<void> esperarResultado() => esperar(tester, find.byType(ResultadoPagoScreen), limite: const Duration(minutes: 15));

    if (!_pagoMp) {
      markTestSkipped('Necesita pagar a mano en Mercado Pago: corre con --dart-define=PAGO_MP=true');
      return;
    }

    // CA-16: compra para recoger en tienda con Mercado Pago; al confirmarla la tienda, la app ofrece pagar.
    await llenarCarrito();
    await tester.tap(find.text('Mercado Pago'));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await esperar(tester, find.text('¡Pedido enviado!'));
    final folio = (tester.widget<Text>(find.textContaining(RegExp(r'^Pedido DL-'))).data!).replaceFirst('Pedido ', '');
    _paso('confirmar $folio');
    await esperarServidor(() => pedido(folio, (p) => p.estado == 'confirmado'), 'el pedido $folio confirmado');
    await tester.tap(find.text('Ver mis pedidos'));
    await esperar(tester, find.text('Pedido $folio'));
    await tester.tap(find.text('Pedido $folio'));
    await esperar(tester, find.byType(SeguimientoScreen));
    await esperar(tester, find.text('Paga con Mercado Pago'));
    _caso('CA-16', 'el pedido $folio confirmado por la tienda ofrece pagar con Mercado Pago');

    // CA-17: pago rechazado; la app avisa que no se completó y deja intentarlo de nuevo.
    await tester.tap(find.byTooltip('Pagar con Mercado Pago'));
    _paso('pagar rechazado');
    await esperarResultado();
    expect(find.text('El pago no se completó'), findsOneWidget);
    expect((await tester.runAsync(() => pedido(folio, (p) => !p.pagado))), isNotNull, reason: 'El servidor marcó pagado un pago rechazado');
    _caso('CA-17', 'con la tarjeta rechazada la app muestra "El pago no se completó" y el pedido sigue sin pagar');

    // CA-18: intenta de nuevo y el pago queda aprobado en la app y en el servidor.
    await tester.tap(find.text('Intentar de nuevo'));
    _paso('pagar aprobado');
    await esperar(tester, find.text('¡Pago recibido!'), limite: const Duration(minutes: 15));
    expect(find.text('Pedido $folio'), findsOneWidget);
    final pagado = await esperarServidor(() => pedido(folio, (p) => p.pagado), 'el pago aprobado de $folio (webhook)');
    _caso('CA-18', 'con la tarjeta aprobada la app muestra "¡Pago recibido!" y el servidor tiene $folio pagado (${formatoPrecioCompleto(pagado.total)})');

    // CA-19: el pedido pagado ya no ofrece pagar.
    await tester.tap(find.text('Ver mi pedido'));
    await esperar(tester, find.byType(SeguimientoScreen));
    await tester.pumpAndSettle();
    expect(find.text('Paga con Mercado Pago'), findsNothing);
    _caso('CA-19', 'el seguimiento de $folio ya no ofrece pagar');
    _navegador(tester).popUntil((ruta) => ruta.isFirst);
    await tester.pumpAndSettle();

    // CA-20: aparta con el pago inicial por Mercado Pago, lo paga y el apartado queda activo.
    await llenarCarrito();
    await tester.tap(find.text('Apartado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semanal'));
    await tester.pump();
    await tester.tap(find.text('Mercado Pago'));
    await tester.pump();
    await tester.tap(find.text('Apartar'));
    await esperar(tester, find.text('¡Piezas apartadas!'));
    final folioApartado = (tester.widget<Text>(find.textContaining(RegExp(r'^Apartado '))).data!).replaceFirst('Apartado ', '');
    await tester.tap(find.text('Ver mis apartados'));
    await esperar(tester, find.byType(MisApartadosScreen));
    await esperar(tester, find.text('Pagar $folioApartado con Mercado Pago'));
    await tester.tap(find.text('Pagar $folioApartado con Mercado Pago'));
    _paso('pagar aprobado');
    await esperar(tester, find.text('¡Pago recibido!'), limite: const Duration(minutes: 15));
    expect(find.text('Apartado $folioApartado'), findsOneWidget);
    await esperarServidor(
      () async => (await pedidosServidor.misApartados()).where((a) => a.folio == folioApartado && a.estado != 'pendiente_pago').firstOrNull,
      'el pago inicial de $folioApartado (webhook)',
    );
    _caso('CA-20', 'el pago inicial de $folioApartado quedó aprobado en la app y el apartado está activo en el servidor');
    await tester.tap(find.text('Ver mis apartados'));
    await tester.pumpAndSettle();
    expect(find.text('Pagar $folioApartado con Mercado Pago'), findsNothing);
    _navegador(tester).popUntil((ruta) => ruta.isFirst);
    await tester.pumpAndSettle();
    expect(find.byType(MisPedidosScreen), findsNothing);
  });
}
