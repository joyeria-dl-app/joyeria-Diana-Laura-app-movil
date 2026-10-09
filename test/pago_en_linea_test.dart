import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/screens/mis_apartados_screen.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';
import 'package:joyeria_diana_laura/utils/pago_en_linea.dart';

// HU-12 · Abrir el pago de Mercado Pago desde el seguimiento del pedido y desde Mis apartados.

const _enlace = 'https://www.mercadopago.com.mx/checkout/v1/redirect?pref_id=2481604929-6d0f1b5e';

class _PagosFalso extends PedidoService {
  _PagosFalso({this.pedidos = const [], this.apartados = const [], this.error}) : super(api: ApiClient());
  final List<Pedido> pedidos;
  final List<Apartado> apartados;
  final PedidoException? error;
  final List<String> pedidas = [];

  @override
  Future<List<Pedido>> misPedidos() async => pedidos;

  @override
  Future<List<Apartado>> misApartados() async => apartados;

  @override
  Future<PreferenciaPago> preferenciaPedido(int pedidoId) async {
    pedidas.add('pedido $pedidoId');
    if (error != null) throw error!;
    return const PreferenciaPago(id: '2481604929-6d0f1b5e', enlace: _enlace);
  }

  @override
  Future<PreferenciaPago> preferenciaApartado(int apartadoId) async {
    pedidas.add('apartado $apartadoId');
    return const PreferenciaPago(id: '2481604929-6d0f1b5e', enlace: _enlace);
  }
}

const _confirmado = Pedido(id: 51, folio: 'DL-1791300000000', estado: 'confirmado', total: 449.5, metodoPagoCodigo: 'mercadopago', estadoPago: 'pendiente');

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
  final abiertos = <Uri>[];
  late Future<bool> Function(Uri) original;

  setUp(() {
    abiertos.clear();
    original = abrirEnlacePago;
    abrirEnlacePago = (uri) async {
      abiertos.add(uri);
      return true;
    };
  });
  tearDown(() => abrirEnlacePago = original);

  testWidgets('Un pedido confirmado con Mercado Pago muestra el pago y abre su enlace', (tester) async {
    final servicio = _PagosFalso(pedidos: const [_confirmado]);
    await _abrir(tester, servicio, const SeguimientoScreen(pedido: _confirmado));

    expect(find.text('Paga con Mercado Pago'), findsOneWidget);
    expect(find.text(r'Tu pedido ya está confirmado · $449.50'), findsOneWidget);
    await tester.tap(find.byTooltip('Pagar con Mercado Pago'));
    await tester.pumpAndSettle();

    expect(servicio.pedidas, ['pedido 51']);
    expect(abiertos, [Uri.parse(_enlace)]);
  });

  testWidgets('Sin confirmar o ya pagado no ofrece pagar', (tester) async {
    for (final p in [
      const Pedido(id: 52, folio: 'DL-2', estado: 'pendiente', total: 10, metodoPagoCodigo: 'mercadopago'),
      const Pedido(id: 53, folio: 'DL-3', estado: 'confirmado', total: 10, metodoPagoCodigo: 'mercadopago', estadoPago: 'aprobado'),
      const Pedido(id: 54, folio: 'DL-4', estado: 'confirmado', total: 10, metodoPagoCodigo: 'efectivo'),
    ]) {
      await _abrir(tester, _PagosFalso(pedidos: [p]), SeguimientoScreen(pedido: p));
      expect(find.text('Paga con Mercado Pago'), findsNothing, reason: p.folio);
    }
  });

  testWidgets('Si el backend no deja pagar muestra su mensaje y no abre nada', (tester) async {
    final servicio = _PagosFalso(error: const PedidoException('El plazo para pagar este pedido ya venció. Haz un pedido nuevo.'));
    await _abrir(tester, servicio, const SeguimientoScreen(pedido: _confirmado));

    await tester.tap(find.byTooltip('Pagar con Mercado Pago'));
    await tester.pumpAndSettle();

    expect(find.text('El plazo para pagar este pedido ya venció. Haz un pedido nuevo.'), findsOneWidget);
    expect(abiertos, isEmpty);
  });

  testWidgets('Un apartado con el pago inicial por Mercado Pago muestra su botón y abre el pago', (tester) async {
    const apartado = Apartado(
      id: 7,
      folio: 'APT-20261009-K3M2Q',
      estado: 'pendiente_pago',
      montoTotal: 899,
      montoPagado: 449.5,
      saldo: 449.5,
      metodoInicial: 'mercadopago',
    );
    final servicio = _PagosFalso(apartados: const [apartado]);
    await _abrir(tester, servicio, const MisApartadosScreen());

    await tester.tap(find.text('Pagar APT-20261009-K3M2Q con Mercado Pago'));
    await tester.pumpAndSettle();

    expect(servicio.pedidas, ['apartado 7']);
    expect(abiertos, [Uri.parse(_enlace)]);
  });

  testWidgets('Un apartado con pago inicial en efectivo no muestra el botón de Mercado Pago', (tester) async {
    const apartado = Apartado(
      id: 8,
      folio: 'APT-20261009-Z9X8W',
      estado: 'pendiente_pago',
      montoTotal: 899,
      montoPagado: 449.5,
      saldo: 449.5,
      metodoInicial: 'efectivo',
    );
    await _abrir(tester, _PagosFalso(apartados: const [apartado]), const MisApartadosScreen());
    expect(find.textContaining('con Mercado Pago'), findsNothing);
  });
}
