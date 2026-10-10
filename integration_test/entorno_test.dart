import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/routes/app_routes.dart';
import 'package:joyeria_diana_laura/screens/mis_pedidos_screen.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;
import 'sesion.dart';

// Pruebas del entorno: cómo se comporta la app ante lo que pasa en el teléfono.
// La app no puede cambiar la batería, recibir una llamada ni quitarse la señal, así que
// lo hace pruebas/entorno.sh desde la computadora con adb: cuando la prueba imprime
// "ENTORNO PASO <caso>", el script aplica la situación en el emulador y la prueba
// comprueba cómo reaccionó la app. Resultados en pruebas/entorno_sprint3.md.
// bash pruebas/entorno.sh
const _correo = String.fromEnvironment('PRUEBAS_CORREO');
const _contrasena = String.fromEnvironment('PRUEBAS_CONTRASENA');

void _paso(String caso) => debugPrint('ENTORNO PASO $caso');
void _caso(String id, String descripcion) => debugPrint('ENTORNO $id Pasa: $descripcion');

Future<void> _espera(WidgetTester tester, Duration duracion) async {
  await tester.runAsync(() => Future<void>.delayed(duracion));
  await tester.pump();
}

// Espera a que la app pase a un estado del ciclo de vida (segundo plano o de regreso).
Future<void> _esperarEstado(WidgetTester tester, bool Function(AppLifecycleState?) condicion, String que) async {
  final fin = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(fin)) {
    if (condicion(WidgetsBinding.instance.lifecycleState)) return;
    await _espera(tester, const Duration(milliseconds: 300));
  }
  fail('La app no $que en 60 s (estado: ${WidgetsBinding.instance.lifecycleState})');
}

NavigatorState _navegador(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('Entorno: batería baja, llamada entrante y sin señal', (tester) async {
    expect(_correo, isNotEmpty, reason: 'Falta PRUEBAS_CORREO');
    expect(_contrasena, isNotEmpty, reason: 'Falta PRUEBAS_CONTRASENA');

    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await iniciarSesion(tester, _correo, _contrasena);

    final contexto = tester.element(find.byType(Scaffold).first);
    final carritoServidor = contexto.read<CarritoService>();
    final carrito = contexto.read<CarritoProvider>();

    // Una compra a medias: una pieza en el carrito y la pantalla del carrito abierta.
    final pieza = (await tester.runAsync(() async {
      final p = (await contexto.read<ProductoService>().productos()).firstWhere((p) => p.stock > 0);
      await carritoServidor.vaciar();
      await carritoServidor.agregar(p.id);
      await carrito.cargar();
      return p;
    }))!;
    _navegador(tester).pushNamed(AppRoutes.carrito);
    await esperar(tester, find.text('Ir a pagar'));
    expect(find.text(pieza.nombre), findsOneWidget);

    // CE-01: con la batería al 5% y sin cargador la app sigue respondiendo.
    _paso('bateria');
    await _espera(tester, const Duration(seconds: 8));
    expect(find.text(pieza.nombre), findsOneWidget);
    _navegador(tester).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver catálogo'));
    await esperar(tester, find.textContaining('piezas'));
    _navegador(tester).popUntil((ruta) => ruta.isFirst);
    _navegador(tester).pushNamed(AppRoutes.carrito);
    await esperar(tester, find.text('Ir a pagar'));
    _caso('CE-01', 'con batería baja la app sigue cargando el catálogo y el carrito');

    Future<void> conservaElCarrito() async {
      await tester.pumpAndSettle();
      expect(find.text(pieza.nombre), findsOneWidget);
      expect(find.text('Ir a pagar'), findsOneWidget);
      await tester.runAsync(carrito.cargar);
      await tester.pump();
      expect(carrito.items.map((i) => i.productoId), contains(pieza.id), reason: 'El servidor ya no tiene la pieza en el carrito');
    }

    // CE-02: llega una llamada a mitad de la compra, se contesta y se cuelga. En Android 14
    // la llamada aparece como aviso encima de la app, así que la app sigue visible.
    _paso('llamada');
    await _espera(tester, const Duration(seconds: 16));
    await conservaElCarrito();
    _caso('CE-02', 'durante la llamada y al colgar la app conserva el carrito y la sesión (estado ${WidgetsBinding.instance.lifecycleState?.name})');

    // CE-03: el cliente sale a la pantalla de inicio (por ejemplo, para contestar) y vuelve
    // a abrir la app: pasa a segundo plano y regresa con el carrito y la sesión.
    _paso('segundo_plano');
    await _esperarEstado(tester, (e) => e != AppLifecycleState.resumed, 'pasó a segundo plano');
    final enSegundoPlano = WidgetsBinding.instance.lifecycleState;
    await _esperarEstado(tester, (e) => e == AppLifecycleState.resumed, 'regresó al primer plano');
    await conservaElCarrito();
    _caso('CE-03', 'la app pasó a ${enSegundoPlano?.name} y al volver conserva el carrito y la sesión');

    // CE-04: sin señal la app avisa sin cerrarse y, al volver la red, carga de nuevo.
    _navegador(tester).popUntil((ruta) => ruta.isFirst);
    await tester.pumpAndSettle();
    _paso('sin_senal');
    await _espera(tester, const Duration(seconds: 8));
    await tester.tap(find.text('Mis pedidos'));
    await tester.pump();
    final fin = DateTime.now().add(const Duration(seconds: 60));
    while (find.text('Sin conexión').evaluate().isEmpty && DateTime.now().isBefore(fin)) {
      await _espera(tester, const Duration(milliseconds: 500));
    }
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    _caso('CE-04', 'sin señal Mis pedidos muestra "Sin conexión" con Reintentar y la app no se cierra');

    _paso('con_senal');
    await _espera(tester, const Duration(seconds: 10));
    await esperar(tester, find.byType(MisPedidosScreen));
    await esperar(tester, find.textContaining('En curso'));
    expect(find.text('Sin conexión'), findsNothing);
    _caso('CE-05', 'al volver la señal y tocar Reintentar, Mis pedidos carga de nuevo');
    await _espera(tester, const Duration(seconds: 3));
    _navegador(tester).pop();
    await tester.pumpAndSettle();

    // Deja la cuenta como estaba.
    await tester.runAsync(() async {
      await carritoServidor.vaciar();
      await carrito.cargar();
    });
    await tester.tap(find.text('Cerrar sesión'));
    await esperar(tester, find.text('Explorar sin cuenta'));
    _paso('fin');
  });
}
