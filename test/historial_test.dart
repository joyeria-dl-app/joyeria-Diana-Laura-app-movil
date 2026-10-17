// TIPO: widget y unitaria
// ALCANCE: HU-14 · historial (#51): abonos de cada apartado y recibo del pedido entregado
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/historial_test.dart
// DATOS: backend simulado en memoria (sin red); apartado con abonos de ejemplo y pedido entregado

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/models/usuario.dart';
import 'package:joyeria_diana_laura/screens/detalle_apartado_screen.dart';
import 'package:joyeria_diana_laura/screens/mis_apartados_screen.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// Respuesta de GET /apartados/:id con la forma real del backend (abonos con su método de pago).
final _detalleJson = {
  'id': 7,
  'folio': 'APT-20261012-K3M8P',
  'estado': 'activo',
  'monto_total': '1250.00',
  'monto_pagado': '875.00',
  'saldo_pendiente': '375.00',
  'fecha_limite_liquidacion': '2026-11-09T06:00:00.000Z',
  'plan_nombre': 'Semanal',
  'productos': [
    {'nombre': 'Anillo lila halo', 'cantidad': 1, 'precio_unitario': '1250.00', 'imagen': null},
  ],
  'abonos': [
    {'id': 21, 'monto': '625.00', 'fecha_abono': '2026-10-12', 'estado': 'pagado', 'metodo_nombre': 'Efectivo en Tienda', 'metodo_codigo': 'efectivo'},
    {'id': 24, 'monto': '250.00', 'fecha_abono': '2026-10-19', 'estado': 'pagado', 'metodo_nombre': 'Transferencia Bancaria', 'metodo_codigo': 'transferencia'},
    {'id': 27, 'monto': '200.00', 'fecha_abono': '2026-10-26', 'estado': 'pendiente', 'metodo_nombre': 'Transferencia Bancaria'},
  ],
};

class _PedidosFalso extends PedidoService {
  _PedidosFalso({this.detalle, this.error}) : super(api: ApiClient());
  Apartado? detalle;
  PedidoException? error;
  int consultas = 0;
  final List<int> recibos = [];

  @override
  Future<List<Apartado>> misApartados() async => [Apartado.fromJson(_detalleJson)];

  @override
  Future<Apartado> detalleApartado(int apartadoId) async {
    consultas++;
    if (error != null) throw error!;
    return detalle!;
  }

  @override
  Future<Uri> enlaceRecibo(int pedidoId) async {
    recibos.add(pedidoId);
    return Uri.parse('https://joyeria.example/api/carrito/pedidos/$pedidoId/recibo?token=t');
  }
}

Future<void> _abrir(WidgetTester tester, PedidoService servicio, Widget pantalla) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<PedidoService>.value(
      value: servicio,
      child: MaterialApp(
        theme: AppTheme.oscuro(),
        home: pantalla,
        routes: {'/login': (_) => const Scaffold(body: Text('Pantalla de login'))},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Responde lo mismo a todas las rutas y guarda qué peticiones se hicieron.
class _Adaptador implements HttpClientAdapter {
  _Adaptador(this.respuesta);
  final Map<String, dynamic> respuesta;
  final List<RequestOptions> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    return ResponseBody.fromString(
      jsonEncode(respuesta),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('Servicio', () {
    test('El detalle del apartado trae cada abono con su método y su estado', () async {
      final adaptador = _Adaptador({'success': true, 'data': _detalleJson});
      final api = ApiClient(dio: Dio(BaseOptions(baseUrl: 'https://joyeria.example/api'))..httpClientAdapter = adaptador);
      final apartado = await PedidoService(api: api).detalleApartado(7);

      expect(adaptador.peticiones.single.path, '/apartados/7');
      expect(apartado.abonos, hasLength(3));
      expect(apartado.abonos.first.monto, 625);
      expect(apartado.abonos.first.metodo, 'Efectivo en Tienda');
      expect(apartado.abonos.first.confirmado, isTrue);
      expect(apartado.abonos.last.confirmado, isFalse);
      // La fecha del abono llega sin hora (fecha de México) y se toma tal cual.
      expect(apartado.abonos.last.fecha, DateTime(2026, 10, 26));
    });

    test('El recibo se abre con la sesión del cliente en el enlace, como en el sitio web', () async {
      final storage = MemorySessionStorage();
      await storage.guardar('token-del-cliente', const Usuario(email: 'ana@correo.com', nombre: 'Ana', rol: 'cliente'));
      final api = ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://joyeria.example/api')),
        storage: storage,
      );

      final enlace = await PedidoService(api: api).enlaceRecibo(51);
      expect(enlace.toString(), 'https://joyeria.example/api/carrito/pedidos/51/recibo?token=token-del-cliente');
    });

    test('Sin sesión no arma el enlace del recibo', () async {
      final api = ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'https://joyeria.example/api')),
        storage: MemorySessionStorage(),
      );
      expect(() => PedidoService(api: api).enlaceRecibo(51), throwsA(isA<PedidoException>().having((e) => e.sinSesion, 'sinSesion', isTrue)));
    });
  });

  group('Historial de abonos', () {
    testWidgets('Al tocar un apartado en Mis apartados se abre su detalle', (tester) async {
      await _abrir(tester, _PedidosFalso(detalle: Apartado.fromJson(_detalleJson)), const MisApartadosScreen());
      await tester.tap(find.textContaining('APT-20261012-K3M8P'));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleApartadoScreen), findsOneWidget);
      expect(find.text('Mi apartado'), findsOneWidget);
    });

    testWidgets('Muestra cada abono del más reciente al más antiguo con método y estado', (tester) async {
      final apartado = Apartado.fromJson(_detalleJson);
      await _abrir(tester, _PedidosFalso(detalle: apartado), DetalleApartadoScreen(apartado: apartado));

      expect(find.text('Abonos · 3'), findsOneWidget);
      expect(find.text(r'$625.00'), findsOneWidget);
      expect(find.text('12 oct · Efectivo en Tienda'), findsOneWidget);
      expect(find.text('19 oct · Transferencia Bancaria'), findsOneWidget);
      expect(find.text('Confirmado'), findsNWidgets(2));
      expect(find.text('Por confirmar'), findsOneWidget);
      // El más reciente (26 oct, por confirmar) va primero.
      expect(tester.getTopLeft(find.text('Por confirmar')).dy, lessThan(tester.getTopLeft(find.text('Confirmado').first).dy));
      expect(find.text(r'Faltan $375.00'), findsOneWidget);
    });

    testWidgets('Un apartado cancelado no muestra saldo ni fecha y su abono pendiente dice que no se confirmó', (tester) async {
      final cancelado = Apartado.fromJson({
        ..._detalleJson,
        'estado': 'cancelado',
        'abonos': [
          {'id': 30, 'monto': '224.75', 'fecha_abono': '2026-10-06', 'estado': 'pendiente', 'metodo_nombre': 'Efectivo en Tienda'},
        ],
      });
      await _abrir(tester, _PedidosFalso(detalle: cancelado), DetalleApartadoScreen(apartado: cancelado));
      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.textContaining('Faltan'), findsNothing);
      expect(find.textContaining('Liquidar antes'), findsNothing);
      expect(find.text('No se confirmó'), findsOneWidget);
      expect(find.text('Por confirmar'), findsNothing);
    });

    testWidgets('Un apartado sin abonos lo dice', (tester) async {
      final sinAbonos = Apartado.fromJson({..._detalleJson, 'abonos': null});
      await _abrir(tester, _PedidosFalso(detalle: sinAbonos), DetalleApartadoScreen(apartado: sinAbonos));
      expect(find.text('Todavía no hay abonos registrados en este apartado.'), findsOneWidget);
    });

    testWidgets('Sin conexión deja reintentar', (tester) async {
      final apartado = Apartado.fromJson(_detalleJson);
      final servicio = _PedidosFalso(detalle: apartado, error: const PedidoException('No se pudo conectar.'));
      await _abrir(tester, servicio, DetalleApartadoScreen(apartado: apartado));
      expect(find.text('Sin conexión'), findsOneWidget);

      servicio.error = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(servicio.consultas, 2);
      expect(find.text('Abonos · 3'), findsOneWidget);
    });

    testWidgets('Sin sesión invita a iniciarla', (tester) async {
      final apartado = Apartado.fromJson(_detalleJson);
      await _abrir(tester, _PedidosFalso(error: const PedidoException('Inicia sesión', sinSesion: true)), DetalleApartadoScreen(apartado: apartado));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla de login'), findsOneWidget);
    });
  });

  group('Recibo', () {
    final abiertos = <Uri>[];
    late Future<bool> Function(Uri) original;
    setUp(() {
      abiertos.clear();
      original = abrirRecibo;
      abrirRecibo = (uri) async {
        abiertos.add(uri);
        return true;
      };
    });
    tearDown(() => abrirRecibo = original);

    testWidgets('Un pedido entregado ofrece su recibo y lo abre', (tester) async {
      final servicio = _PedidosFalso();
      const entregado = Pedido(id: 51, folio: 'DL-1791300000000', estado: 'entregado', total: 449.5, estadoPago: 'aprobado');
      await _abrir(tester, servicio, const SeguimientoScreen(pedido: entregado));

      expect(find.text('Recibo de tu compra'), findsOneWidget);
      await tester.tap(find.byTooltip('Ver o descargar recibo'));
      await tester.pumpAndSettle();
      expect(servicio.recibos, [51]);
      expect(abiertos.single.path, '/api/carrito/pedidos/51/recibo');
    });

    testWidgets('Un pedido que no se ha entregado no ofrece recibo', (tester) async {
      const enCamino = Pedido(id: 52, folio: 'DL-1791300000001', estado: 'enviado', total: 980, estadoPago: 'aprobado', domicilio: true);
      await _abrir(tester, _PedidosFalso(), const SeguimientoScreen(pedido: enCamino));
      expect(find.text('Recibo de tu compra'), findsNothing);
    });
  });
}
