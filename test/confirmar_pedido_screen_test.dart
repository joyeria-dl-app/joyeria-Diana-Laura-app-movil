import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/carrito.dart';
import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/routes/app_routes.dart';
import 'package:joyeria_diana_laura/screens/confirmar_pedido_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// Dos anillos de $580.32: total $1,160.64, como en los bocetos.
class _CarritoFalso extends CarritoService {
  _CarritoFalso() : super(api: ApiClient());
  List<ItemCarrito> items = [const ItemCarrito(id: 1, productoId: 134, nombre: 'Anillos de plata ley .925', cantidad: 2, precioVenta: 580.32, stock: 40)];

  @override
  Future<Carrito> obtener() async => Carrito(items: List.of(items));
}

// Responde con los datos reales del backend y guarda lo que se pidió.
class _PedidosFalso extends PedidoService {
  _PedidosFalso(this.carrito, {this.error}) : super(api: ApiClient());
  final _CarritoFalso carrito;
  PedidoException? error;
  final List<String> llamadas = [];

  static const efectivo = MetodoPago(id: 2, nombre: 'Efectivo en Tienda', codigo: 'efectivo');

  @override
  Future<OpcionesCompra> opciones() async => const OpcionesCompra(
    metodos: [
      MetodoPago(id: 8, nombre: 'PayPal', codigo: 'paypal', enLinea: true),
      MetodoPago(id: 1, nombre: 'Transferencia Bancaria', codigo: 'transferencia'),
      MetodoPago(id: 7, nombre: 'MercadoPago', codigo: 'mercadopago', enLinea: true),
      efectivo,
    ],
    costoEnvio: 200,
  );

  @override
  Future<List<String>> zonas() async => ['Huejutla', 'San Felipe', 'Jaltocan', 'Tampico', 'Tehuetlan'];

  @override
  Future<List<PlanAbono>> planes() async => const [
    PlanAbono(id: 1, nombre: 'Semanal', intervaloDias: 7, porcentaje: 50),
    PlanAbono(id: 2, nombre: 'Quincenal', intervaloDias: 15, porcentaje: 25),
  ];

  @override
  Future<Confirmacion> comprar({required MetodoPago metodo, DireccionEntrega? direccion, double costoEnvio = 0, String? notas}) async {
    if (error != null) throw error!;
    llamadas.add('comprar ${metodo.codigo} ${direccion?.texto ?? 'tienda'} $costoEnvio');
    carrito.items = [];
    return const Confirmacion(folio: 'DL-1791190000000', pedidoId: 41);
  }

  @override
  Future<Confirmacion> apartar({required MetodoPago metodo, required double abonoHoy, PlanAbono? plan}) async {
    llamadas.add('apartar ${metodo.codigo} $abonoHoy ${plan?.nombre}');
    carrito.items = [];
    return const Confirmacion(folio: 'AP-1791190000000', pedidoId: 43);
  }

  @override
  Future<List<Apartado>> misApartados() async => [
    Apartado(
      id: 7,
      folio: 'AP-1791190000000',
      estado: 'pendiente_pago',
      montoTotal: 1160.64,
      montoPagado: 0,
      saldo: 580.32,
      fechaLimite: DateTime(2026, 10, 12),
      plan: 'Semanal',
    ),
  ];
}

Future<_PedidosFalso> _abrir(WidgetTester tester, {PedidoException? error}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final carrito = _CarritoFalso();
  final pedidos = _PedidosFalso(carrito, error: error);
  final provider = CarritoProvider(carrito);
  await provider.cargar();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PedidoService>.value(value: pedidos),
        ChangeNotifierProvider.value(value: provider),
      ],
      child: MaterialApp(theme: AppTheme.oscuro(), home: const ConfirmarPedidoScreen(), routes: {AppRoutes.catalogo: (_) => const Scaffold()}),
    ),
  );
  await tester.pumpAndSettle();
  return pedidos;
}

void main() {
  testWidgets('8a: en tienda con los 4 métodos de pago y el total del carrito', (tester) async {
    await _abrir(tester);

    expect(find.text('Confirmar pedido'), findsOneWidget);
    expect(find.text('Entrega y pago'), findsOneWidget);
    for (final metodo in ['PayPal', 'Transferencia', 'Mercado Pago', 'Efectivo en tienda']) {
      expect(find.text(metodo), findsOneWidget);
    }
    expect(find.text('\$1,160.64'), findsOneWidget);
  });

  testWidgets('8b y 8e: a domicilio pide la dirección, suma el envío y quita el efectivo', (tester) async {
    final pedidos = await _abrir(tester);

    await tester.tap(find.text('A domicilio'));
    await tester.pumpAndSettle();
    expect(find.text('Tu dirección de entrega'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Calle'), 'Morelos');
    await tester.enterText(find.widgetWithText(TextFormField, 'Número'), '12');
    await tester.enterText(find.widgetWithText(TextFormField, 'Colonia'), 'Centro');
    await tester.enterText(find.widgetWithText(TextFormField, 'C.P.'), '43000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), 'Huejutla de Reyes');
    await tester.tap(find.text('Usar esta dirección'));
    await tester.pumpAndSettle();

    expect(find.text('Entregamos en tu zona.'), findsOneWidget);
    expect(find.text('Efectivo en tienda'), findsNothing);
    expect(find.text('\$1,360.64'), findsOneWidget);

    await tester.tap(find.text('Mercado Pago'));
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(pedidos.llamadas.single, 'comprar mercadopago Morelos 12, Centro, Huejutla de Reyes, Hidalgo, CP 43000 200.0');
    expect(find.text('¡Pedido enviado!'), findsOneWidget);
    expect(find.text('Pedido DL-1791190000000'), findsOneWidget);
    expect(find.text('A domicilio'), findsOneWidget);
  });

  testWidgets('8d y 8f: aparta con el 50% y el plan semanal', (tester) async {
    final pedidos = await _abrir(tester);

    await tester.tap(find.text('Apartado'));
    await tester.pumpAndSettle();
    expect(find.text('Apartar piezas'), findsOneWidget);
    expect(find.textContaining('Mínimo \$580.32 (50%)'), findsOneWidget);
    expect(find.text('1 pago de \$580.32 a los 7 días'), findsOneWidget);
    expect(find.text('2 pagos de \$290.16 cada 15 días'), findsOneWidget);

    await tester.tap(find.text('Semanal'));
    await tester.pump();
    await tester.tap(find.text('Apartar'));
    await tester.pumpAndSettle();

    expect(pedidos.llamadas.single, 'apartar efectivo 580.32 Semanal');
    expect(find.text('¡Piezas apartadas!'), findsOneWidget);
    expect(find.text('12 oct'), findsOneWidget);
  });

  testWidgets('8g: muestra el aviso del servidor cuando no hay existencias', (tester) async {
    await _abrir(tester, error: const PedidoException('Stock insuficiente para "Anillos de plata ley .925". Solo quedan 1 unidades.'));

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Stock insuficiente'), findsOneWidget);
    expect(find.text('Confirmar pedido'), findsOneWidget);
  });
}
