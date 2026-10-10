import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/screens/carrito_screen.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/screens/favoritos_screen.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/widgets/tarjeta_producto.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;
import 'sesion.dart';

// Prueba de integración del recorrido del cliente con sesión (HU-07 a HU-10):
// catálogo → filtro → detalle → agregar al carrito → favoritos, contra el backend real.
// La cuenta de prueba va en env.json (PRUEBAS_CORREO y PRUEBAS_CONTRASENA); en GitHub viene de los secretos:
// flutter test integration_test/recorrido_cliente_test.dart --dart-define-from-file=env.json
const _correo = String.fromEnvironment('PRUEBAS_CORREO');
const _contrasena = String.fromEnvironment('PRUEBAS_CONTRASENA');

// Abre la primera pieza del filtro con existencias (las agotadas no se pueden agregar).
Future<void> _abrirPiezaDisponible(WidgetTester tester) async {
  await esperar(tester, find.byType(TarjetaProducto));
  final disponible = find.byWidgetPredicate((w) => w is TarjetaProducto && !w.producto.agotado);
  // Las tarjetas se construyen al desplazarse: se baja hasta que aparezca una disponible.
  final lista = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
  for (var i = 0; i < 20 && disponible.evaluate().isEmpty; i++) {
    await tester.drag(lista, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(disponible, findsWidgets, reason: 'No hay piezas con existencias en el filtro');
  await Scrollable.ensureVisible(tester.element(disponible.first), alignment: 0.3);
  await tester.pumpAndSettle();
  await tester.tap(disponible.first);
  await esperar(tester, find.text('Agregar'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('HU-07 a HU-10: el cliente filtra, abre una pieza, la agrega al carrito y la guarda en favoritos', (tester) async {
    expect(_correo, isNotEmpty, reason: 'Falta PRUEBAS_CORREO');
    expect(_contrasena, isNotEmpty, reason: 'Falta PRUEBAS_CONTRASENA');

    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await iniciarSesion(tester, _correo, _contrasena);

    // Catálogo y filtro por categoría.
    await tester.tap(find.text('Ver catálogo'));
    await esperar(tester, find.textContaining('piezas'));
    await esperar(tester, find.text('Anillos'));
    await tester.tap(find.text('Anillos').first);
    await esperar(tester, find.text('Anillos').at(1));

    // Detalle de una pieza con existencias.
    await _abrirPiezaDisponible(tester);
    final carrito = Provider.of<CarritoProvider>(tester.element(find.byType(DetalleScreen)), listen: false);

    // Agregar al carrito (HU-09) y verlo en el carrito.
    await tester.tap(find.text('Agregar'));
    await esperar(tester, find.text('Agregada a tu carrito'));
    // El aviso entra deslizándose desde abajo: se espera a que termine antes de tocar su botón.
    await tester.pump(const Duration(seconds: 1));
    final pieza = carrito.items.last.nombre;
    await tester.tap(find.text('Ver carrito'));
    await esperar(tester, find.byType(CarritoScreen));
    await esperar(tester, find.text(pieza));

    // Se vacía el carrito para dejar la cuenta como estaba.
    await tester.tap(find.byTooltip('Vaciar carrito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaciar carrito').last);
    await esperar(tester, find.text('Tu carrito está vacío'));
    expect(carrito.items, isEmpty);

    // Regresar al detalle y guardarla en favoritos (HU-10).
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await esperar(tester, find.text('Agregar'));
    if (find.bySemanticsLabel('Quitar de favoritos').evaluate().isNotEmpty) {
      await tester.tap(find.bySemanticsLabel('Quitar de favoritos'));
      await esperar(tester, find.bySemanticsLabel('Guardar en favoritos'));
    }
    await tester.tap(find.bySemanticsLabel('Guardar en favoritos'));
    await esperar(tester, find.text('Guardada en tus favoritos'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Ver favoritos'));
    await esperar(tester, find.byType(FavoritosScreen));
    await esperar(tester, find.text(pieza));

    // Se quita de favoritos para dejar la cuenta como estaba.
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text(pieza), matching: find.byType(TarjetaProducto)),
        matching: find.byIcon(Icons.favorite_rounded),
      ),
    );
    await esperar(tester, find.text('Quitada de tus favoritos'));
    await tester.pumpAndSettle();
    expect(find.text(pieza), findsNothing);

    // Cerrar sesión para que las demás pruebas inicien sin cuenta.
    tester.state<NavigatorState>(find.byType(Navigator).first).popUntil((ruta) => ruta.isFirst);
    await esperar(tester, find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await esperar(tester, find.text('Explorar sin cuenta'));
  });
}
