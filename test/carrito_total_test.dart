import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/models/carrito.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';
import 'package:joyeria_diana_laura/utils/formato.dart';
import 'package:joyeria_diana_laura/widgets/resumen_carrito.dart';

// Carrito en memoria que se comporta como el backend, sin llamarlo.
class _ServicioFalso extends CarritoService {
  _ServicioFalso(this.items, {this.error}) : super(api: ApiClient());
  List<ItemCarrito> items;
  CarritoException? error;
  final List<String> llamadas = [];

  @override
  Future<Carrito> obtener() async {
    llamadas.add('obtener');
    if (error != null) throw error!;
    return Carrito(items: List.of(items));
  }

  @override
  Future<void> cambiarCantidad(int itemId, int cantidad) async {
    llamadas.add('cantidad $itemId $cantidad');
    final item = items.firstWhere((i) => i.id == itemId);
    if (cantidad > item.stock) throw const CarritoException('Stock insuficiente');
    items = [for (final i in items) i.id == itemId ? _pieza(i.id, i.precioVenta, cantidad: cantidad, stock: i.stock) : i];
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

ItemCarrito _pieza(int id, double precio, {int cantidad = 1, double? promocion, int stock = 5}) => ItemCarrito(
      id: id,
      productoId: id + 100,
      nombre: 'Pieza $id',
      cantidad: cantidad,
      precioVenta: precio,
      precioPromocion: promocion,
      stock: stock,
    );

void main() {
  group('Total del carrito', () {
    test('Suma el precio final de cada pieza por su cantidad', () async {
      final carrito = CarritoProvider(_ServicioFalso([_pieza(1, 1250), _pieza(2, 540, cantidad: 2)]));
      await carrito.cargar();

      expect(carrito.subtotal, 2330);
      expect(carrito.total, 2330);
      expect(carrito.piezas, 3);
    });

    test('Usa la promoción cuando la pieza la tiene', () async {
      final carrito = CarritoProvider(_ServicioFalso([_pieza(1, 1250, promocion: 1000, cantidad: 2)]));
      await carrito.cargar();

      expect(carrito.total, 2000);
    });

    test('Al subir la cantidad el total cambia y se guarda en el backend', () async {
      final servicio = _ServicioFalso([_pieza(1, 1250), _pieza(2, 540)]);
      final carrito = CarritoProvider(servicio);
      await carrito.cargar();

      final ok = await carrito.cambiarCantidad(carrito.items.first, 2);

      expect(ok, isTrue);
      expect(carrito.total, 3040);
      expect(servicio.llamadas, ['obtener', 'cantidad 1 2', 'obtener']);
    });

    test('Si no hay existencias avisa y regresa al total real', () async {
      final carrito = CarritoProvider(_ServicioFalso([_pieza(1, 1250, cantidad: 3, stock: 3)]));
      await carrito.cargar();

      final ok = await carrito.cambiarCantidad(carrito.items.first, 4);

      expect(ok, isFalse);
      expect(carrito.aviso, 'Stock insuficiente');
      expect(carrito.total, 3750);
    });

    test('Bajar a cero quita la pieza y el total ya no la cuenta', () async {
      final servicio = _ServicioFalso([_pieza(1, 1250), _pieza(2, 540)]);
      final carrito = CarritoProvider(servicio);
      await carrito.cargar();

      await carrito.cambiarCantidad(carrito.items.last, 0);

      expect(servicio.llamadas, contains('quitar 2'));
      expect(carrito.items.length, 1);
      expect(carrito.total, 1250);
    });

    test('Vaciar deja el total en cero', () async {
      final carrito = CarritoProvider(_ServicioFalso([_pieza(1, 1250)]));
      await carrito.cargar();

      await carrito.vaciar();

      expect(carrito.carrito.vacio, isTrue);
      expect(carrito.total, 0);
    });

    test('Sin sesión no muestra error, pide iniciar sesión', () async {
      final carrito = CarritoProvider(
        _ServicioFalso([], error: const CarritoException('Inicia sesión para usar tu carrito.', sinSesion: true)),
      );
      await carrito.cargar();

      expect(carrito.sinSesion, isTrue);
      expect(carrito.error, isNull);
    });

    test('Sin conexión guarda el mensaje para reintentar', () async {
      final carrito = CarritoProvider(_ServicioFalso([], error: const CarritoException('Sin red')));
      await carrito.cargar();

      expect(carrito.sinSesion, isFalse);
      expect(carrito.error, 'Sin red');
    });
  });

  test('El resumen muestra los precios con centavos', () {
    expect(formatoPrecioCompleto(1790), '\$1,790.00');
    expect(formatoPrecioCompleto(565.4), '\$565.40');
  });

  testWidgets('El resumen muestra subtotal, envío y total como en el boceto 6a', (tester) async {
    var pagos = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.oscuro(),
      home: Scaffold(
        body: const Padding(padding: EdgeInsets.all(20), child: ResumenCarrito(subtotal: 1790, total: 1790)),
        bottomNavigationBar: BarraPagar(total: 1790, onPagar: () => pagos++),
      ),
    ));

    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Se calcula al pagar'), findsOneWidget);
    expect(find.text('\$1,790.00'), findsNWidgets(2));
    expect(find.text('\$1,790'), findsOneWidget);

    await tester.tap(find.text('Ir a pagar'));
    expect(pagos, 1);
  });
}
