import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/screens/mis_apartados_screen.dart';
import 'package:joyeria_diana_laura/screens/mis_pedidos_screen.dart';
import 'package:joyeria_diana_laura/screens/resultado_pago_screen.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';
import 'package:joyeria_diana_laura/utils/pago_en_linea.dart';

// HU-12 · Criterio de aceptación: el cliente paga un pedido o el pago inicial de un
// apartado con Mercado Pago desde la app y, al regresar, ve si el pago quedó aprobado,
// en proceso o no se completó. El backend se simula en memoria; "Mercado Pago" es la
// prueba: decide qué pasó con el pago, avisa al backend (como el webhook) y regresa a
// la app con joyeriadl://pago o sin enlace.

const _enlace = 'https://www.mercadopago.com.mx/checkout/v1/redirect?pref_id=2481604929-6d0f1b5e';

class _Backend extends PedidoService {
  _Backend({List<Pedido>? pedidos, List<Apartado>? apartados}) : pedidos = pedidos ?? [], apartados = apartados ?? [], super(api: ApiClient());
  final List<Pedido> pedidos;
  final List<Apartado> apartados;
  final List<String> preferencias = [];
  // Respuesta del backend al pedir la preferencia (por ejemplo, Mercado Pago caído).
  PedidoException? error;

  @override
  Future<List<Pedido>> misPedidos() async => List.of(pedidos);

  @override
  Future<List<Apartado>> misApartados() async => List.of(apartados);

  @override
  Future<PreferenciaPago> preferenciaPedido(int pedidoId) async {
    if (error != null) throw error!;
    preferencias.add('pedido $pedidoId');
    return const PreferenciaPago(id: '2481604929-6d0f1b5e', enlace: _enlace);
  }

  @override
  Future<PreferenciaPago> preferenciaApartado(int apartadoId) async {
    if (error != null) throw error!;
    preferencias.add('apartado $apartadoId');
    return const PreferenciaPago(id: '2481604929-6d0f1b5e', enlace: _enlace);
  }

  // Webhook de Mercado Pago: el pago del pedido quedó aprobado o en proceso.
  void webhookPedido(int id, String estadoPago) {
    final p = pedidos.firstWhere((p) => p.id == id);
    pedidos[pedidos.indexOf(p)] = Pedido(
      id: p.id,
      folio: p.folio,
      estado: p.estado,
      total: p.total,
      metodoPago: p.metodoPago,
      metodoPagoCodigo: p.metodoPagoCodigo,
      estadoPago: estadoPago,
    );
  }

  // Webhook de Mercado Pago: el pago inicial del apartado quedó aprobado.
  void webhookApartado(int id, double pago) {
    final a = apartados.firstWhere((a) => a.id == id);
    apartados[apartados.indexOf(a)] = Apartado(
      id: a.id,
      folio: a.folio,
      estado: 'activo',
      montoTotal: a.montoTotal,
      montoPagado: pago,
      saldo: a.montoTotal - pago,
      metodoInicial: a.metodoInicial,
    );
  }
}

Pedido _pedido({String estadoPago = 'pendiente'}) => Pedido(
  id: 51,
  folio: 'DL-1791300000000',
  estado: 'confirmado',
  total: 1160.64,
  metodoPago: 'MercadoPago',
  metodoPagoCodigo: 'mercadopago',
  estadoPago: estadoPago,
);

const _apartado = Apartado(
  id: 7,
  folio: 'APT-20261010-K3M2Q',
  estado: 'pendiente_pago',
  montoTotal: 1160.64,
  montoPagado: 0,
  saldo: 1160.64,
  metodoInicial: 'mercadopago',
);

Future<void> _abrir(WidgetTester tester, _Backend backend, Widget inicio) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<PedidoService>.value(
      value: backend,
      child: MaterialApp(theme: AppTheme.oscuro(), home: inicio),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final abiertos = <Uri>[];
  late Future<bool> Function(Uri) originalAbrir;
  late Stream<Uri> Function() originalEnlaces;
  late StreamController<Uri> enlaces;

  setUp(() {
    abiertos.clear();
    originalAbrir = abrirEnlacePago;
    originalEnlaces = enlacesDeRegreso;
    enlaces = StreamController<Uri>.broadcast();
    enlacesDeRegreso = () => enlaces.stream;
    abrirEnlacePago = (uri) async {
      abiertos.add(uri);
      return true;
    };
  });
  tearDown(() {
    abrirEnlacePago = originalAbrir;
    enlacesDeRegreso = originalEnlaces;
    enlaces.close();
  });

  // Deja correr el flujo del enlace, que se creó fuera del reloj falso de la prueba.
  Future<void> esperarRegreso(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
    }
  }

  // Mercado Pago regresa a la app con su enlace (back_url del backend).
  Future<void> regresar(WidgetTester tester, String pago, {String tipo = 'pedido', int id = 51}) async {
    enlaces.add(Uri.parse('joyeriadl://pago?tipo=$tipo&id=$id&pago=$pago'));
    await esperarRegreso(tester);
  }

  // El cliente vuelve a la app sin el enlace (botón Atrás del navegador o desde recientes).
  Future<void> volverSinEnlace(WidgetTester tester) async {
    for (final estado in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(estado);
    }
    for (final estado in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(estado);
    }
    // La app espera 2 s por si todavía llega el enlace.
    await tester.pump(const Duration(milliseconds: 2100));
    await esperarRegreso(tester);
  }

  Future<void> pagarPedido(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Pagar con Mercado Pago'));
    await tester.pumpAndSettle();
  }

  group('Pagar un pedido con Mercado Pago', () {
    testWidgets('Desde Mis pedidos: paga, regresa con el pago aprobado y el pedido ya no ofrece pagar', (tester) async {
      final backend = _Backend(pedidos: [_pedido()]);
      await _abrir(tester, backend, const MisPedidosScreen());

      await tester.tap(find.text('Pedido DL-1791300000000'));
      await tester.pumpAndSettle();
      expect(find.text('Paga con Mercado Pago'), findsOneWidget);
      await pagarPedido(tester);
      expect(backend.preferencias, ['pedido 51']);
      expect(abiertos, [Uri.parse(_enlace)]);

      backend.webhookPedido(51, 'aprobado');
      await regresar(tester, 'exitoso');
      expect(find.text('¡Pago recibido!'), findsOneWidget);
      expect(find.text('Pedido DL-1791300000000'), findsOneWidget);
      expect(find.text(r'$1,160.64'), findsOneWidget);
      expect(find.text('Pagado'), findsOneWidget);

      await tester.tap(find.text('Ver mi pedido'));
      await tester.pumpAndSettle();
      expect(find.byType(SeguimientoScreen), findsOneWidget);
      expect(find.text('Paga con Mercado Pago'), findsNothing);
    });

    testWidgets('Pago rechazado: intenta de nuevo con otra tarjeta y queda aprobado', (tester) async {
      final backend = _Backend(pedidos: [_pedido()]);
      await _abrir(tester, backend, SeguimientoScreen(pedido: _pedido()));

      await pagarPedido(tester);
      await regresar(tester, 'fallido');
      expect(find.text('El pago no se completó'), findsOneWidget);
      expect(find.text('Sin pagar'), findsOneWidget);

      await tester.tap(find.text('Intentar de nuevo'));
      await tester.pumpAndSettle();
      expect(backend.preferencias, ['pedido 51', 'pedido 51']);
      expect(abiertos, hasLength(2));

      backend.webhookPedido(51, 'aprobado');
      await regresar(tester, 'exitoso');
      expect(find.text('¡Pago recibido!'), findsOneWidget);
    });

    testWidgets('Rechazado y "Ahora no": regresa al pedido, que sigue ofreciendo pagar', (tester) async {
      final backend = _Backend(pedidos: [_pedido()]);
      await _abrir(tester, backend, SeguimientoScreen(pedido: _pedido()));

      await pagarPedido(tester);
      await regresar(tester, 'fallido');
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultadoPagoScreen), findsNothing);
      expect(find.text('Paga con Mercado Pago'), findsOneWidget);
      expect(backend.preferencias, ['pedido 51']);
    });

    testWidgets('Pago en OXXO: queda en proceso y, cuando Mercado Pago lo confirma, el pedido aparece pagado', (tester) async {
      final backend = _Backend(pedidos: [_pedido()]);
      await _abrir(tester, backend, SeguimientoScreen(pedido: _pedido()));

      await pagarPedido(tester);
      backend.webhookPedido(51, 'en_proceso');
      await regresar(tester, 'pendiente');
      expect(find.text('Tu pago está en proceso'), findsOneWidget);
      expect(find.text('En proceso'), findsOneWidget);

      // Días después Mercado Pago confirma el pago en OXXO.
      backend.webhookPedido(51, 'aprobado');
      await _abrir(tester, backend, SeguimientoScreen(pedido: (await backend.misPedidos()).single));
      expect(find.text('Paga con Mercado Pago'), findsNothing);
    });

    testWidgets('Lo que registró el servidor manda sobre el enlace de regreso', (tester) async {
      final backend = _Backend(pedidos: [_pedido()]);
      await _abrir(tester, backend, SeguimientoScreen(pedido: _pedido()));

      await pagarPedido(tester);
      backend.webhookPedido(51, 'aprobado');
      await regresar(tester, 'fallido');
      expect(find.text('¡Pago recibido!'), findsOneWidget);
      expect(find.text('El pago no se completó'), findsNothing);
    });

    testWidgets('Vuelve sin el enlace de Mercado Pago: consulta el servidor y muestra el pago aprobado', (tester) async {
      final backend = _Backend(pedidos: [_pedido()]);
      await _abrir(tester, backend, SeguimientoScreen(pedido: _pedido()));

      await pagarPedido(tester);
      backend.webhookPedido(51, 'aprobado');
      await volverSinEnlace(tester);
      expect(find.text('¡Pago recibido!'), findsOneWidget);
    });

    testWidgets('Vuelve sin el enlace y sin pagar: avisa que no vio el pago', (tester) async {
      final backend = _Backend(pedidos: [_pedido()]);
      await _abrir(tester, backend, SeguimientoScreen(pedido: _pedido()));

      await pagarPedido(tester);
      await volverSinEnlace(tester);
      expect(find.byType(ResultadoPagoScreen), findsNothing);
      expect(find.text('No vimos tu pago. Si ya pagaste, en unos momentos se verá aquí.'), findsOneWidget);
      expect(find.text('Paga con Mercado Pago'), findsOneWidget);
    });

    testWidgets('Si Mercado Pago no está disponible avisa y no abre nada', (tester) async {
      final backend = _Backend(pedidos: [_pedido()])
        ..error = const PedidoException('Mercado Pago no está disponible en este momento. Intenta más tarde o elige otro método de pago.');
      await _abrir(tester, backend, SeguimientoScreen(pedido: _pedido()));

      await pagarPedido(tester);
      expect(find.text('Mercado Pago no está disponible en este momento. Intenta más tarde o elige otro método de pago.'), findsOneWidget);
      expect(abiertos, isEmpty);

      // Un enlace que llegue después no muestra ningún resultado.
      await regresar(tester, 'exitoso');
      expect(find.byType(ResultadoPagoScreen), findsNothing);
    });
  });

  group('Pagar el pago inicial de un apartado con Mercado Pago', () {
    testWidgets('Paga desde Mis apartados, regresa aprobado y el apartado queda activo con su saldo', (tester) async {
      final backend = _Backend(apartados: [_apartado]);
      await _abrir(tester, backend, const MisApartadosScreen());

      await tester.tap(find.text('Pagar APT-20261010-K3M2Q con Mercado Pago'));
      await tester.pumpAndSettle();
      expect(backend.preferencias, ['apartado 7']);

      backend.webhookApartado(7, 580.32);
      await regresar(tester, 'exitoso', tipo: 'apartado', id: 7);
      expect(find.text('¡Pago recibido!'), findsOneWidget);
      expect(find.text('Apartado APT-20261010-K3M2Q'), findsOneWidget);
      expect(find.text(r'$580.32'), findsOneWidget);

      await tester.tap(find.text('Ver mis apartados'));
      await tester.pumpAndSettle();
      expect(find.text('Faltan \$580.32'), findsOneWidget);
      expect(find.textContaining('con Mercado Pago'), findsNothing);
    });

    testWidgets('Pago inicial rechazado: "Intentar de nuevo" pide otra preferencia del mismo apartado', (tester) async {
      final backend = _Backend(apartados: [_apartado]);
      await _abrir(tester, backend, const MisApartadosScreen());

      await tester.tap(find.text('Pagar APT-20261010-K3M2Q con Mercado Pago'));
      await tester.pumpAndSettle();
      await regresar(tester, 'fallido', tipo: 'apartado', id: 7);
      expect(find.text('El pago no se completó'), findsOneWidget);

      await tester.tap(find.text('Intentar de nuevo'));
      await tester.pumpAndSettle();
      expect(backend.preferencias, ['apartado 7', 'apartado 7']);
      expect(abiertos, hasLength(2));
    });

    testWidgets('Un enlace de regreso de un pedido no cambia Mis apartados', (tester) async {
      final backend = _Backend(apartados: [_apartado]);
      await _abrir(tester, backend, const MisApartadosScreen());

      await tester.tap(find.text('Pagar APT-20261010-K3M2Q con Mercado Pago'));
      await tester.pumpAndSettle();
      await regresar(tester, 'exitoso', tipo: 'pedido', id: 7);
      expect(find.byType(ResultadoPagoScreen), findsNothing);
    });
  });
}
