// TIPO: unitaria y widget
// ALCANCE: HU-15 · aviso del pedido (#56): mostrarlo con la app abierta y abrir el seguimiento al tocarlo (abierta, en segundo plano o cerrada)
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/avisos_pedido_test.dart
// DATOS: Firebase Cloud Messaging y backend simulados en memoria (sin red); aviso y pedidos de ejemplo

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/screens/abrir_pedido_screen.dart';
import 'package:joyeria_diana_laura/screens/seguimiento_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/avisos_pedido.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

const _datos = {'tipo': 'pedido', 'pedido_id': '51', 'estado': 'confirmado'};

class _FuenteFalsa implements FuenteAvisos {
  final primerPlano = StreamController<AvisoPush>.broadcast();
  final fondo = StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? inicial;
  bool falla = false;
  void Function(Map<String, dynamic>)? tocarLocal;
  final List<AvisoPush> mostrados = [];

  @override
  Future<void> preparar(void Function(Map<String, dynamic> datos) onTocar) async {
    if (falla) throw Exception('sin Firebase');
    tocarLocal = onTocar;
  }

  @override
  Stream<AvisoPush> get enPrimerPlano => primerPlano.stream;

  @override
  Stream<Map<String, dynamic>> get tocadosEnFondo => fondo.stream;

  @override
  Future<Map<String, dynamic>?> avisoInicial() async => inicial;

  @override
  Future<void> mostrar(AvisoPush aviso) async => mostrados.add(aviso);
}

class _PedidosFalso extends PedidoService {
  _PedidosFalso({this.pedidos = const [], this.error}) : super(api: ApiClient());
  List<Pedido> pedidos;
  PedidoException? error;

  @override
  Future<List<Pedido>> misPedidos() async {
    if (error != null) throw error!;
    return pedidos;
  }
}

const _pedido = Pedido(id: 51, folio: 'DL-1791300000051', estado: 'confirmado', total: 1160.64, metodoPago: 'Efectivo en Tienda');

Future<void> _esperar() => Future<void>.delayed(const Duration(milliseconds: 20));

Future<void> _abrir(WidgetTester tester, PedidoService servicio) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<PedidoService>.value(
      value: servicio,
      child: MaterialApp(
        theme: AppTheme.oscuro(),
        home: const AbrirPedidoScreen(pedidoId: 51),
        routes: {
          '/login': (_) => const Scaffold(body: Text('Pantalla de login')),
          '/mis-pedidos': (_) => const Scaffold(body: Text('Pantalla de mis pedidos')),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Avisos', () {
    late _FuenteFalsa fuente;
    late List<int> abiertos;
    late AvisosPedido avisos;

    setUp(() async {
      fuente = _FuenteFalsa();
      abiertos = [];
      avisos = AvisosPedido(fuente: fuente, abrirPedido: abiertos.add);
    });
    tearDown(() => avisos.detener());

    test('Lee el número del pedido del aviso y no confunde otros avisos', () {
      expect(pedidoDelAviso(_datos), 51);
      expect(pedidoDelAviso({'tipo': 'promocion', 'pedido_id': '51'}), isNull);
      expect(pedidoDelAviso({'tipo': 'pedido', 'pedido_id': 'abc'}), isNull);
      expect(pedidoDelAviso({}), isNull);
    });

    test('Con la app abierta muestra el aviso en el canal Pedidos', () async {
      await avisos.iniciar();
      fuente.primerPlano.add(const AvisoPush(titulo: 'Pedido confirmado', cuerpo: 'Confirmamos tu pedido.', datos: _datos));
      await _esperar();

      expect(fuente.mostrados.single.titulo, 'Pedido confirmado');
      expect(abiertos, isEmpty);
    });

    test('Al tocar el aviso con la app abierta abre el pedido', () async {
      await avisos.iniciar();
      fuente.tocarLocal!(_datos);
      expect(abiertos, [51]);
    });

    test('Al tocar el aviso con la app en segundo plano abre el pedido', () async {
      await avisos.iniciar();
      fuente.fondo.add(_datos);
      await _esperar();
      expect(abiertos, [51]);
    });

    test('Si el aviso abrió la app cerrada, abre el pedido al iniciar', () async {
      fuente.inicial = _datos;
      await avisos.iniciar();
      expect(abiertos, [51]);
    });

    test('Un aviso que no es de un pedido no abre nada', () async {
      await avisos.iniciar();
      fuente.fondo.add({'tipo': 'otro'});
      await _esperar();
      expect(abiertos, isEmpty);
    });

    test('Si Firebase no está disponible no rompe la app', () async {
      fuente.falla = true;
      await avisos.iniciar();
      expect(abiertos, isEmpty);
    });
  });

  group('Abrir el pedido del aviso', () {
    testWidgets('Muestra el seguimiento del pedido del aviso', (tester) async {
      await _abrir(tester, _PedidosFalso(pedidos: [_pedido]));
      expect(find.byType(SeguimientoScreen), findsOneWidget);
      expect(find.textContaining('DL-1791300000051'), findsWidgets);
    });

    testWidgets('Si el pedido no es de la cuenta lo dice y lleva a Mis pedidos', (tester) async {
      await _abrir(tester, _PedidosFalso());
      expect(find.text('No encontramos ese pedido'), findsOneWidget);
      await tester.tap(find.text('Ver mis pedidos'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla de mis pedidos'), findsOneWidget);
    });

    testWidgets('Sin sesión invita a iniciarla', (tester) async {
      await _abrir(tester, _PedidosFalso(error: const PedidoException('Inicia sesión', sinSesion: true)));
      expect(find.text('Inicia sesión para ver tu pedido'), findsOneWidget);
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla de login'), findsOneWidget);
    });

    testWidgets('Sin conexión deja reintentar y entonces muestra el pedido', (tester) async {
      final servicio = _PedidosFalso(pedidos: [_pedido], error: const PedidoException('Sin conexión'));
      await _abrir(tester, servicio);
      expect(find.text('Sin conexión'), findsOneWidget);

      servicio.error = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byType(SeguimientoScreen), findsOneWidget);
    });
  });
}
