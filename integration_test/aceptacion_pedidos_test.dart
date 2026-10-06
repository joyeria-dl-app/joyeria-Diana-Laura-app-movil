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
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/utils/formato.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;

// Pruebas de aceptación de HU-11 en el emulador contra el backend real.
// Cada caso (CA-10 a CA-15) sale del criterio de aceptación; la tabla con los
// resultados está en pruebas/aceptacion_hu11.md.
//
// CA-10 a CA-13 hacen una compra y un apartado reales (avisan a la tienda y
// reservan la pieza), así que solo corren con --dart-define=CREAR_PEDIDO=true;
// después la tienda los cancela desde el panel. CA-14 y CA-15 solo leen y corren
// siempre, también en el pipeline de cada integración a develop.
// flutter test integration_test/aceptacion_pedidos_test.dart --dart-define-from-file=env.json --dart-define=CREAR_PEDIDO=true
// Con --dart-define=PAUSA_WEB=40 se detiene 40 s en CA-14 para tomar la captura del sitio web.
const _correo = String.fromEnvironment('PRUEBAS_CORREO');
const _contrasena = String.fromEnvironment('PRUEBAS_CONTRASENA');
const _crearPedido = bool.fromEnvironment('CREAR_PEDIDO');
const _pausaWeb = int.fromEnvironment('PAUSA_WEB');

void _caso(String id, String descripcion) => debugPrint('ACEPTACION $id Pasa: $descripcion');

Future<void> _pausaParaCaptura(WidgetTester tester, String caso) async {
  if (_pausaWeb <= 0) return;
  debugPrint('ACEPTACION $caso: toma ahora la captura del sitio web ($_pausaWeb s)');
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: _pausaWeb)));
}

NavigatorState _navegador(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('Aceptación HU-11: comprar o apartar y ver el estado del pedido', (tester) async {
    expect(_correo, isNotEmpty, reason: 'Falta PRUEBAS_CORREO');
    expect(_contrasena, isNotEmpty, reason: 'Falta PRUEBAS_CONTRASENA');

    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await esperar(tester, find.byType(FilledButton));

    // Inicio de sesión con la cuenta de prueba.
    if (find.text('Ver catálogo').evaluate().isEmpty) {
      await tester.tap(find.text('Iniciar sesión'));
      await esperar(tester, find.byKey(const Key('login_email')));
      await tester.enterText(find.descendant(of: find.byKey(const Key('login_email')), matching: find.byType(EditableText)), _correo);
      await tester.enterText(find.descendant(of: find.byKey(const Key('login_password')), matching: find.byType(EditableText)), _contrasena);
      await tester.tap(find.text('Iniciar sesión').last);
    }
    await esperar(tester, find.text('Ver catálogo'));

    // Servicios con la misma sesión de la app: devuelven lo que guarda el servidor para la cuenta.
    final contexto = tester.element(find.byType(Scaffold).first);
    final pedidosServidor = contexto.read<PedidoService>();
    final carritoServidor = contexto.read<CarritoService>();
    final carrito = contexto.read<CarritoProvider>();

    if (_crearPedido) {
      // Pieza de prueba: el anillo más barato con al menos 2 piezas en existencia.
      final pieza = (await tester.runAsync(() async {
        final productos = contexto.read<ProductoService>();
        final anillos = (await productos.categorias()).firstWhere((c) => c.nombre == 'Anillos');
        final lista = (await productos.productos(categoriaId: anillos.id)).where((p) => p.stock >= 2).toList()
          ..sort((a, b) => a.precioFinal.compareTo(b.precioFinal));
        return lista.isEmpty ? null : lista.first;
      }))!;
      expect(pieza, isNotNull, reason: 'Ningún anillo tiene 2 piezas en existencia');

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

      // CA-10: compra para recoger en tienda en efectivo; el pedido queda en el servidor.
      await llenarCarrito();
      await tester.tap(find.text('Efectivo en tienda'));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await esperar(tester, find.text('¡Pedido enviado!'));
      final folioPedido = (tester.widget<Text>(find.textContaining(RegExp(r'^Pedido DL-'))).data!).replaceFirst('Pedido ', '');
      final enServidor = (await tester.runAsync(pedidosServidor.misPedidos))!.where((p) => p.folio == folioPedido).firstOrNull;
      expect(enServidor, isNotNull, reason: 'El servidor no tiene el pedido $folioPedido');
      expect(enServidor!.estado, 'pendiente');
      expect(enServidor.total, closeTo(pieza.precioFinal, 0.01));
      expect((await tester.runAsync(carritoServidor.obtener))!.items, isEmpty);
      _caso('CA-10', 'el pedido $folioPedido de ${formatoPrecioCompleto(pieza.precioFinal)} quedó en el servidor y el carrito se vació');

      // CA-11: el pedido aparece en Mis pedidos y su seguimiento muestra el estado.
      await tester.tap(find.text('Ver mis pedidos'));
      await esperar(tester, find.byType(MisPedidosScreen));
      await esperar(tester, find.text('Pedido $folioPedido'));
      await tester.tap(find.text('Pedido $folioPedido'));
      await esperar(tester, find.byType(SeguimientoScreen));
      await tester.pumpAndSettle();
      expect(find.text('Pedido recibido'), findsOneWidget);
      expect(find.text('Pendiente'), findsWidgets);
      if (enServidor.codigoEntrega != null) expect(find.text('Código de entrega: ${enServidor.codigoEntrega}'), findsOneWidget);
      _caso('CA-11', 'Mis pedidos muestra $folioPedido y su seguimiento está en Pendiente');
      _navegador(tester).popUntil((ruta) => ruta.isFirst);
      await tester.pumpAndSettle();

      // CA-12: aparta con el 50% y el plan semanal; el apartado queda en el servidor.
      await llenarCarrito();
      await tester.tap(find.text('Apartado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Semanal'));
      await tester.pump();
      await tester.tap(find.text('Efectivo en tienda'));
      await tester.pump();
      await tester.tap(find.text('Apartar'));
      await esperar(tester, find.text('¡Piezas apartadas!'));
      final folioApartado = (tester.widget<Text>(find.textContaining(RegExp(r'^Apartado '))).data!).replaceFirst('Apartado ', '');
      final apartado = (await tester.runAsync(pedidosServidor.misApartados))!.where((a) => a.folio == folioApartado).firstOrNull;
      expect(apartado, isNotNull, reason: 'El servidor no tiene el apartado $folioApartado');
      expect(apartado!.estado, 'pendiente_pago');
      expect(apartado.plan, 'Semanal');
      _caso('CA-12', 'el apartado $folioApartado con plan Semanal quedó en el servidor');

      // CA-13: aparece en Mis apartados con el pago inicial pendiente y todavía no deja abonar.
      await tester.tap(find.text('Ver mis apartados'));
      await esperar(tester, find.byType(MisApartadosScreen));
      await esperar(tester, find.textContaining(folioApartado));
      final tarjeta = find.ancestor(of: find.textContaining(folioApartado), matching: find.byType(Container)).first;
      expect(find.descendant(of: tarjeta, matching: find.text('Pago inicial pendiente')), findsOneWidget);
      if ((await tester.runAsync(pedidosServidor.misApartados))!.every((a) => !a.puedeAbonar)) {
        await tester.tap(find.text('Abonar'));
        await tester.pump();
        expect(find.textContaining('Podrás abonar cuando la tienda confirme'), findsOneWidget);
      }
      _caso('CA-13', 'Mis apartados muestra $folioApartado con el pago inicial pendiente');
      _navegador(tester).popUntil((ruta) => ruta.isFirst);
      await tester.pumpAndSettle();
    }

    // CA-14: Mis pedidos de la app coincide con el servidor (lo que ve el sitio web).
    final pedidos = (await tester.runAsync(pedidosServidor.misPedidos))!;
    await tester.tap(find.text('Mis pedidos'));
    await esperar(tester, find.byType(MisPedidosScreen));
    final enCurso = pedidos.where((p) => p.enCurso).toList();
    await esperar(tester, find.text('En curso · ${enCurso.length}'));
    if (enCurso.isNotEmpty) expect(find.text('Pedido ${enCurso.first.folio}'), findsOneWidget);
    _caso('CA-14', '${enCurso.length} pedidos en curso, igual que en el servidor');
    await _pausaParaCaptura(tester, 'CA-14');
    _navegador(tester).pop();
    await tester.pumpAndSettle();

    // CA-15: Mis apartados de la app coincide con el servidor.
    final apartados = (await tester.runAsync(pedidosServidor.misApartados))!;
    final activos = apartados.where((a) => a.activo).toList();
    await tester.tap(find.text('Mis apartados'));
    await esperar(tester, find.byType(MisApartadosScreen));
    if (activos.isEmpty) {
      await esperar(tester, find.text('No tienes apartados'));
    } else {
      final falta = activos.fold<double>(0, (s, Apartado a) => s + a.saldo);
      await esperar(tester, find.text(formatoPrecioCompleto(falta)));
      expect(find.text('en ${activos.length} ${activos.length == 1 ? 'apartado activo' : 'apartados activos'}'), findsOneWidget);
    }
    _caso('CA-15', '${activos.length} apartados activos, igual que en el servidor');
    _navegador(tester).pop();
    await tester.pumpAndSettle();

    // Cerrar sesión para que las demás pruebas inicien sin cuenta.
    await esperar(tester, find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await esperar(tester, find.text('Explorar sin cuenta'));
  });
}
