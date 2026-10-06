import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/screens/mis_apartados_screen.dart';
import 'package:joyeria_diana_laura/screens/mis_pedidos_screen.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

class _PedidosFalso extends PedidoService {
  _PedidosFalso({this.pedidos = const [], this.apartados = const []}) : super(api: ApiClient());
  final List<Pedido> pedidos;
  final List<Apartado> apartados;

  @override
  Future<List<Pedido>> misPedidos() async => pedidos;

  @override
  Future<List<Apartado>> misApartados() async => apartados;

  final List<String> abonos = [];

  @override
  Future<OpcionesCompra> opciones() async => const OpcionesCompra(
    metodos: [
      MetodoPago(id: 1, nombre: 'Transferencia Bancaria', codigo: 'transferencia'),
      MetodoPago(id: 2, nombre: 'Efectivo en Tienda', codigo: 'efectivo'),
      MetodoPago(id: 7, nombre: 'MercadoPago', codigo: 'mercadopago', enLinea: true),
    ],
    costoEnvio: 200,
  );

  @override
  Future<void> solicitarAbono(int apartadoId, {required double monto, required MetodoPago metodo, List<int>? comprobante, String? nombreArchivo}) async {
    abonos.add('$apartadoId $monto ${metodo.codigo}');
  }
}

const _pieza = PiezaPedido(nombre: 'Anillos de plata ley .925', cantidad: 2, precioUnitario: 580.32);

// Pedido a domicilio enviado con guía (9a y 9c).
final _enviado = Pedido(
  id: 41,
  folio: 'DL-1791190000000',
  estado: 'enviado',
  total: 1360.64,
  domicilio: true,
  direccion: 'Morelos 12, Centro, Huejutla de Reyes, Hidalgo, CP 43000',
  metodoPago: 'MercadoPago',
  fechaCreacion: DateTime(2026, 10, 5, 10, 15),
  fechaEstimada: DateTime(2026, 10, 8),
  numeroGuia: '7712 4471 0098',
  paqueteria: 'Estafeta',
  piezas: const [_pieza],
  historial: [
    CambioEstado(estado: 'confirmado', fecha: DateTime(2026, 10, 5, 12, 40)),
    CambioEstado(estado: 'en_preparacion', fecha: DateTime(2026, 10, 6, 9, 30)),
    CambioEstado(estado: 'enviado', fecha: DateTime(2026, 10, 7, 11, 5)),
  ],
);

// En tienda con código de entrega (9d).
final _enTienda = Pedido(
  id: 42,
  folio: 'DL-1791190000001',
  estado: 'en_preparacion',
  total: 500,
  codigoEntrega: 'Z37EF7',
  fechaCreacion: DateTime(2026, 10, 5, 10, 15),
  piezas: const [_pieza],
  historial: [CambioEstado(estado: 'confirmado', fecha: DateTime(2026, 10, 5, 12, 40))],
);

// Transferencia sin comprobante (9e).
final _transferencia = Pedido(
  id: 43,
  folio: 'DL-1791190000002',
  estado: 'pendiente',
  total: 594.36,
  metodoPago: 'Transferencia Bancaria',
  metodoPagoCodigo: 'transferencia',
  fechaCreacion: DateTime(2026, 10, 5, 10, 15),
);

final _entregado = Pedido(id: 44, folio: 'DL-1791190000003', estado: 'entregado', total: 300, fechaCreacion: DateTime(2026, 9, 30));

Future<void> _abrir(WidgetTester tester, PedidoService servicio, Widget pantalla) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<PedidoService>.value(
      value: servicio,
      child: MaterialApp(theme: AppTheme.oscuro(), home: pantalla),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('9a: separa en curso, entregados y cancelados; el primero en curso muestra su línea de tiempo', (tester) async {
    await _abrir(tester, _PedidosFalso(pedidos: [_enviado, _transferencia, _entregado]), const MisPedidosScreen());

    expect(find.text('En curso · 2'), findsOneWidget);
    expect(find.text('Llega el jueves 8'), findsOneWidget);
    expect(find.text('Pedido recibido'), findsOneWidget);
    expect(find.text('7 oct · 11:05'), findsOneWidget);
    expect(find.text('Pedido DL-1791190000002'), findsOneWidget);
    expect(find.text('Pedido DL-1791190000003'), findsNothing);

    await tester.tap(find.text('Entregados'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido DL-1791190000003'), findsOneWidget);
  });

  testWidgets('9b: sin pedidos invita a ver el catálogo', (tester) async {
    await _abrir(tester, _PedidosFalso(), const MisPedidosScreen());

    expect(find.text('En curso · 0'), findsOneWidget);
    expect(find.text('Aún no tienes pedidos'), findsOneWidget);
    expect(find.text('Ver catálogo'), findsOneWidget);
  });

  testWidgets('9c: a domicilio muestra la guía y la paquetería', (tester) async {
    await _abrir(tester, _PedidosFalso(), SeguimientoScreen(pedido: _enviado));

    expect(find.text('Llega el jueves 8 de octubre'), findsOneWidget);
    expect(find.text('Guía 7712 4471 0098'), findsOneWidget);
    expect(find.textContaining('Estafeta'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
  });

  testWidgets('9d: en tienda muestra el código de entrega', (tester) async {
    await _abrir(tester, _PedidosFalso(), SeguimientoScreen(pedido: _enTienda));

    expect(find.text('Lo recoges en tienda'), findsOneWidget);
    expect(find.text('Código de entrega: Z37EF7'), findsOneWidget);
    expect(find.text('Recogido en tienda'), findsOneWidget);
    expect(find.text('Enviado'), findsNothing);
  });

  testWidgets('9e: transferencia sin comprobante pide subirlo', (tester) async {
    await _abrir(tester, _PedidosFalso(), SeguimientoScreen(pedido: _transferencia));

    expect(find.text('Esperamos tu transferencia'), findsOneWidget);
    expect(find.text('Sube tu comprobante'), findsOneWidget);
    expect(find.byTooltip('Elegir foto del comprobante'), findsOneWidget);
  });

  testWidgets('10a: suma lo que falta de los apartados activos', (tester) async {
    final servicio = _PedidosFalso(
      apartados: [
        Apartado(
          id: 7,
          folio: 'AP-1',
          estado: 'activo',
          montoTotal: 1160.64,
          montoPagado: 580.32,
          saldo: 580.32,
          fechaLimite: DateTime.now().add(const Duration(days: 30)),
          piezas: const [_pieza],
        ),
        Apartado(
          id: 8,
          folio: 'AP-2',
          estado: 'activo',
          montoTotal: 580.32,
          montoPagado: 290.16,
          saldo: 290.16,
          fechaLimite: DateTime.now().add(const Duration(days: 2)),
        ),
      ],
    );
    await _abrir(tester, servicio, const MisApartadosScreen());

    expect(find.text('\$870.48'), findsOneWidget);
    expect(find.text('en 2 apartados activos'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Al corriente'), findsOneWidget);
    expect(find.text('2 días'), findsOneWidget);
    expect(find.text('Faltan \$580.32'), findsOneWidget);
    expect(find.text('Abonar'), findsOneWidget);
  });

  testWidgets('10b: sin apartados invita a ir al carrito', (tester) async {
    await _abrir(tester, _PedidosFalso(), const MisApartadosScreen());

    expect(find.text('No tienes apartados'), findsOneWidget);
    expect(find.text('Ir al carrito'), findsOneWidget);
    expect(find.text('Abonar'), findsNothing);
  });

  testWidgets('Abonar: con el plan semanal sugiere su cuota y registra el abono en tienda', (tester) async {
    final servicio = _PedidosFalso(
      apartados: [
        Apartado(
          id: 7,
          folio: 'AP-1',
          estado: 'activo',
          montoTotal: 1000,
          montoPagado: 500,
          saldo: 500,
          planPorcentaje: 25,
          fechaLimite: DateTime.now().add(const Duration(days: 20)),
        ),
      ],
    );
    await _abrir(tester, servicio, const MisApartadosScreen());

    await tester.tap(find.text('Abonar'));
    await tester.pumpAndSettle();
    expect(find.text('Abonar a tu apartado'), findsOneWidget);
    expect(find.text('\$250.00'), findsOneWidget);

    await tester.tap(find.text('Efectivo en tienda'));
    await tester.pump();
    await tester.tap(find.text('Avisar que pagaré en tienda'));
    await tester.pumpAndSettle();
    expect(servicio.abonos, ['7 250.0 efectivo']);
  });

  testWidgets('Abonar: sin pago inicial confirmado avisa que todavía no se puede', (tester) async {
    final servicio = _PedidosFalso(
      apartados: [Apartado(id: 9, folio: 'AP-9', estado: 'pendiente_pago', montoTotal: 500, montoPagado: 250, saldo: 250)],
    );
    await _abrir(tester, servicio, const MisApartadosScreen());

    await tester.tap(find.text('Abonar'));
    await tester.pump();
    expect(find.text('Podrás abonar cuando la tienda confirme tu pago inicial.'), findsOneWidget);
    expect(servicio.abonos, isEmpty);
  });
}
