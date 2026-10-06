import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/carrito.dart';
import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/routes/app_routes.dart';
import 'package:joyeria_diana_laura/screens/confirmar_pedido_screen.dart';
import 'package:joyeria_diana_laura/screens/mis_apartados_screen.dart';
import 'package:joyeria_diana_laura/screens/mis_pedidos_screen.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// HU-11 · Criterio de aceptación: el cliente compra o aparta las piezas de su
// carrito y ve el estado de su pedido; lo que confirma la tienda se refleja en
// la app. El backend se simula en memoria y lo comparten la app y la tienda.

const _efectivo = MetodoPago(id: 2, nombre: 'Efectivo en Tienda', codigo: 'efectivo');

class _Carrito extends CarritoService {
  _Carrito() : super(api: ApiClient());
  List<ItemCarrito> items = [const ItemCarrito(id: 1, productoId: 134, nombre: 'Anillos de plata ley .925', cantidad: 2, precioVenta: 580.32, stock: 40)];

  @override
  Future<Carrito> obtener() async => Carrito(items: List.of(items));
}

// Pedidos y apartados guardados en el "backend"; los métodos de "tienda" hacen lo que el trabajador en el panel.
class _Backend extends PedidoService {
  _Backend(this.carrito, {List<Pedido>? pedidos}) : pedidos = pedidos ?? [], super(api: ApiClient());
  final _Carrito carrito;
  final List<Pedido> pedidos;
  final List<Apartado> apartados = [];

  double get _totalCarrito => carrito.items.fold(0, (s, i) => s + i.precioVenta * i.cantidad);

  @override
  Future<OpcionesCompra> opciones() async => const OpcionesCompra(
    metodos: [
      MetodoPago(id: 1, nombre: 'Transferencia Bancaria', codigo: 'transferencia'),
      MetodoPago(id: 7, nombre: 'MercadoPago', codigo: 'mercadopago', enLinea: true),
      _efectivo,
    ],
    costoEnvio: 200,
  );

  @override
  Future<List<String>> zonas() async => ['Huejutla'];

  @override
  Future<List<PlanAbono>> planes() async => const [
    PlanAbono(id: 1, nombre: 'Semanal', intervaloDias: 7, porcentaje: 50),
    PlanAbono(id: 2, nombre: 'Quincenal', intervaloDias: 15, porcentaje: 25),
  ];

  @override
  Future<Confirmacion> comprar({required MetodoPago metodo, DireccionEntrega? direccion, double costoEnvio = 0, String? notas}) async {
    final id = 100 + pedidos.length;
    pedidos.add(
      Pedido(
        id: id,
        folio: 'DL-1791190000$id',
        estado: 'pendiente',
        total: _totalCarrito,
        metodoPago: metodo.nombre,
        metodoPagoCodigo: metodo.codigo,
        codigoEntrega: 'Z37EF7',
        fechaCreacion: DateTime(2026, 10, 6, 10, 15),
        piezas: [for (final i in carrito.items) PiezaPedido(nombre: i.nombre, cantidad: i.cantidad, precioUnitario: i.precioVenta)],
      ),
    );
    carrito.items = [];
    return Confirmacion(folio: 'DL-1791190000$id', pedidoId: id);
  }

  @override
  Future<Confirmacion> apartar({required MetodoPago metodo, required double abonoHoy, PlanAbono? plan}) async {
    final total = _totalCarrito;
    apartados.add(
      Apartado(
        id: 7,
        folio: 'AP-1791190000000',
        estado: 'pendiente_pago',
        montoTotal: total,
        montoPagado: 0,
        saldo: total,
        fechaLimite: DateTime.now().add(const Duration(days: 30)),
        plan: plan?.nombre,
        planPorcentaje: plan?.porcentaje,
        abonoPorConfirmar: true,
      ),
    );
    abonoInicial = abonoHoy;
    carrito.items = [];
    return const Confirmacion(folio: 'AP-1791190000000', pedidoId: 43);
  }

  double abonoInicial = 0;
  final List<String> abonos = [];

  @override
  Future<List<Pedido>> misPedidos() async => List.of(pedidos);

  @override
  Future<List<Apartado>> misApartados() async => List.of(apartados);

  @override
  Future<void> solicitarAbono(int apartadoId, {required double monto, required MetodoPago metodo, List<int>? comprobante, String? nombreArchivo}) async {
    abonos.add('$apartadoId $monto ${metodo.codigo}');
    _cambiar(apartadoId, montoPagado: _apartado(apartadoId).montoPagado, porConfirmar: true);
  }

  // Tienda: cambia el estado del pedido y lo deja en el historial.
  void avanzar(int id, String estado, DateTime fecha) {
    final p = pedidos.firstWhere((p) => p.id == id);
    pedidos[pedidos.indexOf(p)] = Pedido(
      id: p.id,
      folio: p.folio,
      estado: estado,
      total: p.total,
      metodoPago: p.metodoPago,
      metodoPagoCodigo: p.metodoPagoCodigo,
      codigoEntrega: p.codigoEntrega,
      fechaCreacion: p.fechaCreacion,
      piezas: p.piezas,
      historial: [
        ...p.historial,
        CambioEstado(estado: estado, fecha: fecha),
      ],
    );
  }

  // Tienda: confirma el pago inicial o el abono que mandó el cliente.
  void confirmarPago(int apartadoId, double monto) => _cambiar(apartadoId, montoPagado: _apartado(apartadoId).montoPagado + monto, porConfirmar: false);

  Apartado _apartado(int id) => apartados.firstWhere((a) => a.id == id);

  void _cambiar(int id, {required double montoPagado, required bool porConfirmar}) {
    final a = _apartado(id);
    final saldo = double.parse((a.montoTotal - montoPagado).toStringAsFixed(2));
    apartados[apartados.indexOf(a)] = Apartado(
      id: a.id,
      folio: a.folio,
      estado: saldo <= 0 ? 'liquidado' : 'activo',
      montoTotal: a.montoTotal,
      montoPagado: montoPagado,
      saldo: saldo,
      fechaLimite: a.fechaLimite,
      plan: a.plan,
      planPorcentaje: a.planPorcentaje,
      abonoPorConfirmar: porConfirmar,
    );
  }
}

Future<void> _abrir(WidgetTester tester, _Backend backend, Widget inicio) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final carrito = CarritoProvider(backend.carrito);
  await carrito.cargar();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PedidoService>.value(value: backend),
        ChangeNotifierProvider.value(value: carrito),
      ],
      child: MaterialApp(
        theme: AppTheme.oscuro(),
        home: inicio,
        routes: {
          AppRoutes.misPedidos: (_) => const MisPedidosScreen(),
          AppRoutes.misApartados: (_) => const MisApartadosScreen(),
          AppRoutes.catalogo: (_) => const Scaffold(),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Comprar para recoger en tienda: el pedido aparece en Mis pedidos con su código de entrega', (tester) async {
    final backend = _Backend(_Carrito());
    await _abrir(tester, backend, const ConfirmarPedidoScreen());

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(backend.pedidos.single.total, 1160.64);
    expect(backend.carrito.items, isEmpty);

    await tester.tap(find.text('Ver mis pedidos'));
    await tester.pumpAndSettle();
    expect(find.byType(MisPedidosScreen), findsOneWidget);
    expect(find.text('En curso · 1'), findsOneWidget);
    expect(find.text('Pedido DL-1791190000100'), findsOneWidget);

    await tester.tap(find.text('Pedido DL-1791190000100'));
    await tester.pumpAndSettle();
    expect(find.byType(SeguimientoScreen), findsOneWidget);
    expect(find.text('Código de entrega: Z37EF7'), findsOneWidget);
  });

  testWidgets('Lo que la tienda confirma se ve en la línea de tiempo con su fecha', (tester) async {
    final backend = _Backend(_Carrito());
    await backend.comprar(metodo: _efectivo);
    backend
      ..avanzar(100, 'confirmado', DateTime(2026, 10, 6, 12, 40))
      ..avanzar(100, 'en_preparacion', DateTime(2026, 10, 7, 9, 30));
    await _abrir(tester, backend, SeguimientoScreen(pedido: backend.pedidos.single));

    expect(find.text('6 oct · 10:15'), findsOneWidget);
    expect(find.text('6 oct · 12:40'), findsOneWidget);
    expect(find.text('7 oct · 09:30'), findsOneWidget);
    expect(find.text('Recogido en tienda'), findsOneWidget);
  });

  testWidgets('Un pedido entregado pasa de En curso a Entregados', (tester) async {
    final backend = _Backend(_Carrito());
    await backend.comprar(metodo: _efectivo);
    backend.avanzar(100, 'entregado', DateTime(2026, 10, 8, 17));
    await _abrir(tester, backend, const MisPedidosScreen());

    expect(find.text('En curso · 0'), findsOneWidget);
    await tester.tap(find.text('Entregados'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido DL-1791190000100'), findsOneWidget);
  });

  testWidgets('Apartar con el plan quincenal: aparece en Mis apartados con el pago inicial pendiente', (tester) async {
    final backend = _Backend(_Carrito());
    await _abrir(tester, backend, const ConfirmarPedidoScreen());

    await tester.tap(find.text('Apartado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quincenal'));
    await tester.pump();
    await tester.tap(find.text('Apartar'));
    await tester.pumpAndSettle();
    expect(backend.abonoInicial, 580.32);

    await tester.tap(find.text('Ver mis apartados'));
    await tester.pumpAndSettle();
    expect(find.byType(MisApartadosScreen), findsOneWidget);
    expect(find.text('Pago inicial pendiente'), findsOneWidget);

    await tester.tap(find.text('Abonar'));
    await tester.pump();
    expect(find.text('Podrás abonar cuando la tienda confirme tu pago inicial.'), findsOneWidget);
    expect(backend.abonos, isEmpty);
  });

  testWidgets('Con el pago inicial confirmado abona la cuota del plan y queda por confirmar', (tester) async {
    final backend = _Backend(_Carrito());
    await backend.apartar(metodo: _efectivo, abonoHoy: 580.32, plan: (await backend.planes())[1]);
    backend.confirmarPago(7, 580.32);
    await _abrir(tester, backend, const MisApartadosScreen());

    expect(find.text('Faltan \$580.32'), findsOneWidget);
    await tester.tap(find.text('Abonar'));
    await tester.pumpAndSettle();
    expect(find.text('\$290.16'), findsOneWidget);

    await tester.tap(find.text('Efectivo en tienda'));
    await tester.pump();
    await tester.tap(find.text('Avisar que pagaré en tienda'));
    await tester.pumpAndSettle();

    expect(backend.abonos, ['7 290.16 efectivo']);
    expect(find.text('Abono por confirmar'), findsOneWidget);
  });

  testWidgets('Cuando la tienda confirma el abono baja el saldo', (tester) async {
    final backend = _Backend(_Carrito());
    await backend.apartar(metodo: _efectivo, abonoHoy: 580.32, plan: (await backend.planes())[1]);
    backend
      ..confirmarPago(7, 580.32)
      ..confirmarPago(7, 290.16);
    await _abrir(tester, backend, const MisApartadosScreen());

    expect(find.text('Faltan \$290.16'), findsOneWidget);
    expect(find.text('Abono por confirmar'), findsNothing);
    expect(find.text('75%'), findsOneWidget);
  });
}
