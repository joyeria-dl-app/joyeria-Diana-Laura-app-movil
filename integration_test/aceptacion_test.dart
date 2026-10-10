import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/screens/carrito_screen.dart';
import 'package:joyeria_diana_laura/screens/catalogo_screen.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/screens/favoritos_screen.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/utils/formato.dart';
import 'package:joyeria_diana_laura/widgets/galeria_fotos.dart';
import 'package:joyeria_diana_laura/widgets/tarjeta_producto.dart';

import 'catalogo_test.dart' show despertarServidor, esperar;
import 'sesion.dart';

// Pruebas de aceptación de HU-08, HU-09 y HU-10 en el emulador contra el backend real.
// Cada caso (CA-01 a CA-09) sale del criterio de aceptación de su historia; la tabla con
// los resultados está en pruebas/aceptacion_sprint2.md.
// "Lo que ve el sitio web" se comprueba con lo que devuelve el servidor para la misma cuenta,
// que es de donde lee el sitio web.
// flutter test integration_test/aceptacion_test.dart --dart-define-from-file=env.json
// Con --dart-define=PAUSA_WEB=40 se detiene 40 s en CA-06 y CA-08 para tomar la captura del sitio web.
const _correo = String.fromEnvironment('PRUEBAS_CORREO');
const _contrasena = String.fromEnvironment('PRUEBAS_CONTRASENA');
const _pausaWeb = int.fromEnvironment('PAUSA_WEB');

void _caso(String id, String descripcion) => debugPrint('ACEPTACION $id Pasa: $descripcion');

Future<void> _pausaParaCaptura(WidgetTester tester, String caso) async {
  if (_pausaWeb <= 0) return;
  debugPrint('ACEPTACION $caso: toma ahora la captura del sitio web ($_pausaWeb s)');
  await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: _pausaWeb)));
}

// Consulta el servidor hasta que se cumpla la condición (máximo 10 s).
Future<bool> _enServidor(WidgetTester tester, Future<bool> Function() condicion) async {
  for (var i = 0; i < 10; i++) {
    if ((await tester.runAsync(condicion))!) return true;
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await tester.pump();
  }
  return false;
}

NavigatorState _navegador(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('Aceptación HU-08, HU-09 y HU-10: detalle con galería, carrito y favoritos', (tester) async {
    expect(_correo, isNotEmpty, reason: 'Falta PRUEBAS_CORREO');
    expect(_contrasena, isNotEmpty, reason: 'Falta PRUEBAS_CONTRASENA');

    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await iniciarSesion(tester, _correo, _contrasena);

    // Servicios con la misma sesión de la app: devuelven lo que guarda el servidor para la cuenta.
    final contexto = tester.element(find.byType(Scaffold).first);
    final productos = contexto.read<ProductoService>();
    final carritoServidor = contexto.read<CarritoService>();
    final favoritosServidor = contexto.read<FavoritoService>();

    // La cuenta empieza sin piezas en el carrito.
    await tester.runAsync(carritoServidor.vaciar);

    // Pieza de prueba: el primer anillo con existencias y más de una foto.
    final (anillos, pieza) = (await tester.runAsync(() async {
      final anillos = (await productos.categorias()).firstWhere((c) => c.nombre == 'Anillos');
      for (final p in await productos.productos(categoriaId: anillos.id)) {
        if (p.agotado) continue;
        final detalle = await productos.detalle(p.id);
        if (detalle.imagenes.length > 1) return (anillos, detalle);
      }
      return (anillos, null);
    }))!;
    expect(pieza, isNotNull, reason: 'Ningún anillo con existencias tiene más de una foto');
    final detalle = pieza!;
    final producto = detalle.producto;

    // Si la pieza quedó en favoritos de otra corrida, se quita para empezar igual.
    if ((await tester.runAsync(() => favoritosServidor.esFavorito(producto.id)))!) {
      await tester.runAsync(() => favoritosServidor.alternar(producto.id));
    }

    // Catálogo filtrado por Anillos hasta la tarjeta de la pieza.
    await tester.tap(find.text('Ver catálogo'));
    await esperar(tester, find.byType(TarjetaProducto));
    await tester.tap(find.text(anillos.nombre).first);
    await esperar(tester, find.text(anillos.nombre).at(1));
    final tarjeta = find.byWidgetPredicate((w) => w is TarjetaProducto && w.producto.id == producto.id);
    final lista = find
        .descendant(of: find.byType(CatalogoScreen), matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down))
        .first;
    for (var i = 0; i < 20 && tarjeta.evaluate().isEmpty; i++) {
      await tester.drag(lista, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(tarjeta, findsOneWidget, reason: 'La pieza de prueba no aparece en el catálogo');
    await Scrollable.ensureVisible(tester.element(tarjeta), alignment: 0.3);
    await tester.pumpAndSettle();

    // CA-01 (HU-08): al tocar la pieza se abre su detalle con descripción y precio.
    await tester.tap(tarjeta);
    await esperar(tester, find.text('Precio'));
    expect(find.byType(DetalleScreen), findsOneWidget);
    expect(find.text(producto.nombre), findsWidgets);
    expect(find.textContaining(formatoPrecioCompleto(producto.precioFinal), findRichText: true), findsWidgets);
    if (detalle.descripcion?.trim().isNotEmpty ?? false) {
      expect(find.textContaining(detalle.descripcion!.trim().substring(0, 20)), findsOneWidget);
    }
    _caso('CA-01', 'el detalle de "${producto.nombre}" muestra descripción y precio');

    // CA-02 (HU-08): se deslizan todas las fotos de la galería.
    final paginas = find.descendant(of: find.byType(GaleriaFotos), matching: find.byType(PageView));
    final fotos = detalle.imagenes.length;
    for (var i = 1; i < fotos; i++) {
      await tester.fling(paginas, const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
    }
    expect(tester.widget<PageView>(paginas).controller!.page!.round(), fotos - 1, reason: 'No se llegó a la última foto');
    _caso('CA-02', 'se deslizaron las $fotos fotos de la galería');

    // CA-03 (HU-09): agregar la pieza y verla en el carrito.
    final carrito = contexto.read<CarritoProvider>();
    await tester.tap(find.text('Agregar'));
    await esperar(tester, find.text('Agregada a tu carrito'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Ver carrito'));
    await esperar(tester, find.byType(CarritoScreen));
    await esperar(tester, find.text(producto.nombre));
    _caso('CA-03', 'la pieza agregada aparece en el carrito');

    // CA-04 (HU-09): al cambiar la cantidad el total se actualiza.
    final precio = carrito.items.single.precioFinal;
    await tester.tap(find.bySemanticsLabel('Agregar una'));
    await esperar(tester, find.text('2'));
    await tester.pumpAndSettle();
    expect(carrito.items.single.cantidad, 2);
    expect(carrito.total, closeTo(precio * 2, 0.01));
    expect(find.text(formatoPrecioCompleto(precio * 2)), findsWidgets);
    _caso('CA-04', 'con 2 piezas el total es ${formatoPrecioCompleto(precio * 2)}');

    // CA-06 (HU-09): el carrito de la app coincide con el del sitio web (misma cuenta).
    final enServidor = (await tester.runAsync(carritoServidor.obtener))!;
    expect(enServidor.items.map((i) => (i.productoId, i.cantidad)), carrito.items.map((i) => (i.productoId, i.cantidad)));
    expect(enServidor.items.single.cantidad, 2);
    _caso('CA-06', 'el servidor (sitio web) tiene la misma pieza con cantidad 2');
    await _pausaParaCaptura(tester, 'CA-06');

    // CA-05 (HU-09): al quitar la pieza sale del carrito (también en el servidor).
    await tester.drag(find.text(producto.nombre), const Offset(-500, 0));
    await esperar(tester, find.text('Tu carrito está vacío'));
    // La app quita la pieza en pantalla al instante y avisa al servidor en segundo plano: se espera su respuesta.
    expect(await _enServidor(tester, () async => (await carritoServidor.obtener()).items.isEmpty), isTrue, reason: 'El servidor sigue con la pieza');
    _caso('CA-05', 'al quitarla el carrito queda vacío en la app y en el servidor');

    // CA-07 (HU-10): marcarla como favorita desde el detalle y verla en la lista.
    _navegador(tester).pop();
    await esperar(tester, find.bySemanticsLabel('Guardar en favoritos'));
    await tester.tap(find.bySemanticsLabel('Guardar en favoritos'));
    await esperar(tester, find.text('Guardada en tus favoritos'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Ver favoritos'));
    await esperar(tester, find.byType(FavoritosScreen));
    await esperar(tester, find.text(producto.nombre));
    _caso('CA-07', 'la pieza marcada aparece en Favoritos');

    // CA-08 (HU-10): también aparece en los favoritos del sitio web.
    expect(await _enServidor(tester, () async => (await favoritosServidor.lista()).any((p) => p.id == producto.id)), isTrue);
    _caso('CA-08', 'el servidor (sitio web) tiene la pieza en favoritos');
    await _pausaParaCaptura(tester, 'CA-08');

    // CA-09 (HU-10): al quitarla desaparece de la lista (también en el servidor).
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text(producto.nombre), matching: find.byType(TarjetaProducto)),
        matching: find.byIcon(Icons.favorite_rounded),
      ),
    );
    await esperar(tester, find.text('Quitada de tus favoritos'));
    await tester.pumpAndSettle();
    expect(find.text(producto.nombre), findsNothing);
    expect(
      await _enServidor(tester, () async => !(await favoritosServidor.lista()).any((p) => p.id == producto.id)),
      isTrue,
      reason: 'El servidor sigue con la pieza en favoritos',
    );
    _caso('CA-09', 'al quitarla desaparece de Favoritos en la app y en el servidor');

    // Cerrar sesión para que las demás pruebas inicien sin cuenta.
    _navegador(tester).popUntil((ruta) => ruta.isFirst);
    await esperar(tester, find.text('Cerrar sesión'));
    await tester.tap(find.text('Cerrar sesión'));
    await esperar(tester, find.text('Explorar sin cuenta'));
  });
}
