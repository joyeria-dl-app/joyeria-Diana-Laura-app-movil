import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/carrito.dart';
import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/routes/app_routes.dart';
import 'package:joyeria_diana_laura/screens/carrito_screen.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';
import 'package:joyeria_diana_laura/widgets/barra_navegacion.dart';

// HU-09 · Criterio de aceptación: el cliente agrega piezas y el carrito de la
// app coincide con el que ve en el sitio web. El backend se simula en memoria
// guardando las piezas por cuenta, como lo hace el real.

// Pieza que ofrece el catálogo en estas pruebas.
const _anillo = Producto(id: 58, nombre: 'Anillo corazón', precioVenta: 1250, precioPromocion: 1000, stock: 4, categoriaNombre: 'Anillos');

class _Catalogo extends ProductoService {
  _Catalogo() : super(api: ApiClient());

  @override
  Future<DetalleProducto> detalle(int id) async => const DetalleProducto(producto: _anillo, medidas: 'Talla 7');
}

// Carrito guardado en el "backend": lo comparten la app y el sitio web.
class _Backend extends CarritoService {
  _Backend() : super(api: ApiClient());
  final List<ItemCarrito> guardado = [];
  int _siguiente = 300;

  @override
  Future<Carrito> obtener() async => Carrito(items: List.of(guardado));

  @override
  Future<void> agregar(int productoId, {int cantidad = 1, String? talla}) async {
    // Como el backend (ON CONFLICT usuario, producto y talla): misma pieza y talla, mismo renglón.
    final i = guardado.indexWhere((p) => p.productoId == productoId && p.talla == talla);
    if (i >= 0) return cambiarCantidad(guardado[i].id, guardado[i].cantidad + cantidad);
    guardado.add(_renglon(_siguiente++, cantidad, talla));
  }

  @override
  Future<void> cambiarCantidad(int itemId, int cantidad) async {
    final i = guardado.indexWhere((p) => p.id == itemId);
    guardado[i] = _renglon(itemId, cantidad, guardado[i].talla);
  }

  @override
  Future<void> quitar(int itemId) async => guardado.removeWhere((p) => p.id == itemId);

  ItemCarrito _renglon(int id, int cantidad, String? talla) => ItemCarrito(
    id: id,
    productoId: _anillo.id,
    nombre: _anillo.nombre,
    cantidad: cantidad,
    precioVenta: _anillo.precioVenta,
    precioPromocion: _anillo.precioPromocion,
    stock: _anillo.stock,
    talla: talla,
  );

  // Lo que mostraría el sitio web con la misma cuenta: piezas y total.
  double get totalWeb => guardado.fold(0, (s, p) => s + p.precioFinal * p.cantidad);
}

Future<void> _abrir(WidgetTester tester, _Backend backend, Widget inicio) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ProductoService>.value(value: _Catalogo()),
        ChangeNotifierProvider(create: (_) => CarritoProvider(backend)),
      ],
      child: MaterialApp(theme: AppTheme.oscuro(), home: inicio, routes: {AppRoutes.carrito: (_) => const CarritoScreen()}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Agregar desde el detalle y abrir el carrito muestra la pieza con su total', (tester) async {
    final backend = _Backend();
    await _abrir(tester, backend, const DetalleScreen(productoId: 58));

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver carrito'));
    await tester.pumpAndSettle();

    expect(find.text('Anillo corazón'), findsOneWidget);
    expect(find.text('Talla 7'), findsOneWidget);
    // Precio con promoción, igual que en el sitio web: en la pieza y en la barra de pagar.
    expect(find.text('\$1,000'), findsNWidgets(2));
    expect(find.text('\$1,000.00'), findsNWidgets(2));
    expect(backend.totalWeb, 1000);
  });

  testWidgets('Agregar dos veces la misma pieza suma la cantidad en un solo renglón', (tester) async {
    final backend = _Backend();
    await _abrir(tester, backend, const DetalleScreen(productoId: 58));

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(backend.guardado.single.cantidad, 2);
    expect(backend.totalWeb, 2000);
  });

  testWidgets('Los cambios en la app quedan en el carrito del sitio web', (tester) async {
    final backend = _Backend()..guardado.add(_Backend()._renglon(300, 1, 'Talla 7'));
    await _abrir(tester, backend, const CarritoScreen());

    await tester.tap(find.bySemanticsLabel('Agregar una'));
    await tester.pumpAndSettle();

    expect(backend.guardado.single.cantidad, 2);
    expect(find.text('\$2,000.00'), findsNWidgets(2));
    expect(backend.totalWeb, 2000);
  });

  testWidgets('Bajar a cero con − quita la pieza y deja el carrito vacío', (tester) async {
    final backend = _Backend()..guardado.add(_Backend()._renglon(300, 1, null));
    await _abrir(tester, backend, const CarritoScreen());

    await tester.tap(find.bySemanticsLabel('Quitar una'));
    await tester.pumpAndSettle();

    expect(backend.guardado, isEmpty);
    expect(find.text('Tu carrito está vacío'), findsOneWidget);
  });

  testWidgets('Lo que se agregó en el sitio web aparece al abrir el carrito', (tester) async {
    final backend = _Backend()..guardado.add(_Backend()._renglon(300, 3, 'Talla 7'));
    await _abrir(tester, backend, const CarritoScreen());

    expect(find.text('3 PIEZAS'), findsOneWidget);
    expect(find.text('\$3,000.00'), findsNWidgets(2));
  });

  testWidgets('El botón Carrito de la barra inferior abre el carrito', (tester) async {
    final backend = _Backend();
    await _abrir(
      tester,
      backend,
      const Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: BarraNavegacion(actual: Seccion.catalogo),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Carrito'));
    await tester.pumpAndSettle();

    expect(find.byType(CarritoScreen), findsOneWidget);
  });
}
