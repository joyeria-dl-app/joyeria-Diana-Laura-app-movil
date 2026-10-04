import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/carrito.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/screens/carrito_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// Carrito en memoria que se comporta como el backend, sin llamarlo.
class _ServicioFalso extends CarritoService {
  _ServicioFalso(this.items, {this.error}) : super(api: ApiClient());
  List<ItemCarrito> items;
  CarritoException? error;
  final List<String> llamadas = [];

  @override
  Future<Carrito> obtener() async {
    if (error != null) throw error!;
    return Carrito(items: List.of(items));
  }

  @override
  Future<void> cambiarCantidad(int itemId, int cantidad) async {
    llamadas.add('cantidad $itemId $cantidad');
    items = [for (final i in items) i.id == itemId ? _pieza(i.id, i.nombre, i.precioVenta, cantidad: cantidad, stock: i.stock) : i];
  }

  @override
  Future<void> quitar(int itemId) async {
    llamadas.add('quitar $itemId');
    items = items.where((i) => i.id != itemId).toList();
  }

  @override
  Future<void> vaciar() async {
    llamadas.add('vaciar');
    items = [];
  }
}

ItemCarrito _pieza(int id, String nombre, double precio, {int cantidad = 1, int stock = 5, String? talla}) => ItemCarrito(
      id: id,
      productoId: id + 100,
      nombre: nombre,
      cantidad: cantidad,
      precioVenta: precio,
      stock: stock,
      talla: talla,
      categoriaNombre: 'Aretes',
    );

final _anillo = _pieza(1, 'Anillo corazón', 1250, talla: 'Talla 7');
final _aretes = _pieza(2, 'Aretes gota', 540);

Future<void> _abrir(WidgetTester tester, _ServicioFalso servicio) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => CarritoProvider(servicio),
      child: MaterialApp(theme: AppTheme.oscuro(), home: const CarritoScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Con piezas muestra cada una, el resumen y la barra para pagar (6a)', (tester) async {
    await _abrir(tester, _ServicioFalso([_anillo, _aretes]));

    expect(find.text('2 PIEZAS'), findsOneWidget);
    expect(find.text('Anillo corazón'), findsOneWidget);
    expect(find.text('Talla 7'), findsOneWidget);
    expect(find.text('Aretes'), findsOneWidget);
    expect(find.text('\$1,250'), findsOneWidget);
    expect(find.text('\$1,790.00'), findsNWidgets(2));
    expect(find.text('Ir a pagar'), findsOneWidget);
    expect(find.bySemanticsLabel('Carrito'), findsNothing);
  });

  testWidgets('Al tocar + sube la cantidad y el total', (tester) async {
    final servicio = _ServicioFalso([_anillo, _aretes]);
    await _abrir(tester, servicio);

    await tester.tap(find.bySemanticsLabel('Agregar una').first);
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['cantidad 1 2']);
    expect(find.text('\$3,040.00'), findsNWidgets(2));
  });

  testWidgets('Sin más existencias desactiva + y avisa cuántas quedan (6g)', (tester) async {
    final servicio = _ServicioFalso([_pieza(1, 'Anillo corazón', 1250, cantidad: 3, stock: 3)]);
    await _abrir(tester, servicio);

    expect(find.text('Solo quedan 3 piezas disponibles.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Agregar una'));
    await tester.pumpAndSettle();
    expect(servicio.llamadas, isEmpty);
  });

  testWidgets('Deslizar una pieza la quita del carrito', (tester) async {
    final servicio = _ServicioFalso([_anillo, _aretes]);
    await _abrir(tester, servicio);

    await tester.drag(find.text('Aretes gota'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['quitar 2']);
    expect(find.text('Aretes gota'), findsNothing);
    expect(find.text('\$1,250.00'), findsNWidgets(2));
  });

  testWidgets('Vaciar pide confirmación y deja el carrito vacío (6f y 6c)', (tester) async {
    final servicio = _ServicioFalso([_anillo, _aretes]);
    await _abrir(tester, servicio);

    await tester.tap(find.byTooltip('Vaciar carrito'));
    await tester.pumpAndSettle();
    expect(find.text('¿Vaciar el carrito?'), findsOneWidget);

    await tester.tap(find.text('Vaciar carrito'));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, ['vaciar']);
    expect(find.text('Tu carrito está vacío'), findsOneWidget);
    expect(find.text('Ver catálogo'), findsOneWidget);
  });

  testWidgets('Cancelar no vacía el carrito', (tester) async {
    final servicio = _ServicioFalso([_anillo]);
    await _abrir(tester, servicio);

    await tester.tap(find.byTooltip('Vaciar carrito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, isEmpty);
    expect(find.text('Anillo corazón'), findsOneWidget);
  });

  testWidgets('Sin sesión pide iniciar sesión (6d)', (tester) async {
    await _abrir(tester, _ServicioFalso([], error: const CarritoException('Inicia sesión', sinSesion: true)));

    expect(find.text('Inicia sesión para usar tu carrito'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.bySemanticsLabel('Carrito'), findsOneWidget);
  });

  testWidgets('Sin conexión permite reintentar y luego muestra las piezas (6e)', (tester) async {
    final servicio = _ServicioFalso([_anillo], error: const CarritoException('Sin red'));
    await _abrir(tester, servicio);
    expect(find.text('Sin conexión'), findsOneWidget);

    servicio.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Anillo corazón'), findsOneWidget);
  });
}
