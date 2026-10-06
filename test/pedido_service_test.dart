import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/models/pedido.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';

// Responde según la ruta y guarda qué peticiones se hicieron.
class _AdaptadorFalso implements HttpClientAdapter {
  _AdaptadorFalso(this.respuestas, {this.status = 200});
  final Map<String, Map<String, dynamic>> respuestas;
  final int status;
  final List<RequestOptions> peticiones = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    peticiones.add(options);
    final respuesta = respuestas['${options.method} ${options.path}'] ?? {'success': false, 'message': 'Ruta no simulada'};
    return ResponseBody.fromString(
      jsonEncode(respuesta),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

// Formas reales de las respuestas del backend.
const _metodos = {
  'success': true,
  'data': {
    'metodos': [
      {'id': 8, 'nombre': 'PayPal', 'codigo': 'paypal', 'tipo': 'pasarela', 'es_pasarela': true},
      {'id': 1, 'nombre': 'Transferencia Bancaria', 'codigo': 'transferencia', 'tipo': 'transferencia', 'es_pasarela': false},
      {'id': 7, 'nombre': 'MercadoPago', 'codigo': 'mercadopago', 'tipo': 'pasarela', 'es_pasarela': true},
      {'id': 2, 'nombre': 'Efectivo en Tienda', 'codigo': 'efectivo', 'tipo': 'efectivo', 'es_pasarela': false},
    ],
    'costo_envio': 200,
  },
};

const _pedido = {
  'id': 41,
  'folio': 'DL-1791190000000',
  'estado': 'enviado',
  'total': '1360.64',
  'costo_envio': '200.00',
  'tipo_entrega': 'domicilio',
  'direccion_envio': 'Morelos 12, Centro, Huejutla de Reyes, Hidalgo, CP 43000',
  'metodo_pago_nombre': 'MercadoPago',
  'metodo_pago_codigo': 'mercadopago',
  'estado_pago': 'aprobado',
  'fecha_creacion': '2026-10-05T16:15:00.000Z',
  'fecha_estimada_entrega': '2026-10-08T06:00:00.000Z',
  'numero_guia': '7712 4471 0098',
  'paqueteria': 'Estafeta',
  'codigo_entrega': null,
  'items': [
    {'producto_nombre': 'Anillos de plata ley .925', 'producto_imagen': 'https://res.cloudinary.com/x/a.jpg', 'cantidad': 2, 'precio_unitario': '580.32'},
  ],
  'historial': [
    {'estado': 'confirmado', 'fecha': '2026-10-05T18:40:00.000Z', 'comentario': null},
    {'estado': 'en_preparacion', 'fecha': '2026-10-06T15:30:00.000Z', 'comentario': null},
    {'estado': 'enviado', 'fecha': '2026-10-07T17:05:00.000Z', 'comentario': 'Va con Estafeta'},
  ],
};

void main() {
  late _AdaptadorFalso backend;

  PedidoService crear(Map<String, Map<String, dynamic>> respuestas, {int status = 200}) {
    backend = _AdaptadorFalso(respuestas, status: status);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = backend;
    return PedidoService(api: ApiClient(dio: dio));
  }

  Map<String, dynamic> cuerpo(int i) => backend.peticiones[i].data as Map<String, dynamic>;

  test('Trae los métodos de pago y el costo de envío; el efectivo solo aplica en tienda', () async {
    final opciones = await crear({'GET /carrito/metodos-pago': _metodos}).opciones();

    expect(opciones.costoEnvio, 200);
    expect(opciones.metodos.map((m) => m.codigo), ['paypal', 'transferencia', 'mercadopago', 'efectivo']);
    expect(opciones.metodos.firstWhere((m) => m.codigo == 'mercadopago').enLinea, isTrue);
    expect(opciones.metodosPara(domicilio: true).map((m) => m.codigo), isNot(contains('efectivo')));
    expect(opciones.metodosPara(domicilio: false).map((m) => m.codigo), contains('efectivo'));
  });

  test('Trae las zonas de entrega activas y los planes de apartado', () async {
    final servicio = crear({
      'GET /zonas-entrega': {
        'success': true,
        'data': [
          {'id': 1, 'nombre': 'Huejutla', 'activo': true},
          {'id': 9, 'nombre': 'Pachuca', 'activo': false},
        ],
      },
      'GET /apartados/planes': {
        'success': true,
        'data': [
          {'id': 1, 'nombre': 'Semanal', 'intervalo_dias': 7, 'porcentaje_abono': '50', 'activo': true},
          {'id': 2, 'nombre': 'Quincenal', 'intervalo_dias': 15, 'porcentaje_abono': '25', 'activo': true},
        ],
      },
    });

    expect(await servicio.zonas(), ['Huejutla']);
    final planes = await servicio.planes();
    expect(planes.map((p) => p.nombre), ['Semanal', 'Quincenal']);
    // Total $1,160.64 con abono del 50%: Semanal 1 pago de $580.32; Quincenal 2 de $290.16.
    expect(planes[0].pagos(total: 1160.64, abonoHoy: 580.32), [580.32]);
    expect(planes[1].pagos(total: 1160.64, abonoHoy: 580.32), [290.16, 290.16]);
  });

  test('Compra para recoger en tienda con el método elegido', () async {
    final servicio = crear({
      'POST /carrito/pedidos': {
        'success': true,
        'data': {'id': 41, 'folio': 'DL-1791190000000'},
      },
    });

    final hecho = await servicio.comprar(
      metodo: const MetodoPago(id: 2, nombre: 'Efectivo en Tienda', codigo: 'efectivo'),
    );

    expect(hecho.folio, 'DL-1791190000000');
    expect(cuerpo(0), {
      'direccion_envio': 'Recoger en tienda',
      'notas_cliente': '',
      'metodo_pago_id': 2,
      'tipo_entrega': 'tienda',
      'costo_envio': 0,
      'direccion_data': null,
    });
  });

  test('Compra a domicilio con la dirección y el costo de envío', () async {
    final servicio = crear({
      'POST /carrito/pedidos': {
        'success': true,
        'data': {'id': 42, 'folio': 'DL-1791190000001'},
      },
    });
    const direccion = DireccionEntrega(calle: 'Morelos', numero: '12', colonia: 'Centro', ciudad: 'Huejutla de Reyes', codigoPostal: '43000');

    await servicio.comprar(
      metodo: const MetodoPago(id: 7, nombre: 'MercadoPago', codigo: 'mercadopago', enLinea: true),
      direccion: direccion,
      costoEnvio: 200,
    );

    expect(cuerpo(0)['tipo_entrega'], 'domicilio');
    expect(cuerpo(0)['costo_envio'], 200);
    expect(cuerpo(0)['direccion_envio'], 'Morelos 12, Centro, Huejutla de Reyes, Hidalgo, CP 43000');
    expect((cuerpo(0)['direccion_data'] as Map)['codigo_postal'], '43000');
    expect((cuerpo(0)['direccion_data'] as Map)['estado_dir'], 'Hidalgo');
  });

  test('Aparta: crea el pedido en tienda y luego el apartado con el abono y el plan', () async {
    final servicio = crear({
      'POST /carrito/pedidos': {
        'success': true,
        'data': {'id': 43, 'folio': 'DL-1791190000002'},
      },
      'POST /apartados': {
        'success': true,
        'data': {
          'folio': 'AP-1791190000000',
          'apartado': {'id': 7},
        },
      },
    });

    final hecho = await servicio.apartar(
      metodo: const MetodoPago(id: 2, nombre: 'Efectivo en Tienda', codigo: 'efectivo'),
      abonoHoy: 580.32,
      plan: const PlanAbono(id: 1, nombre: 'Semanal', intervaloDias: 7, porcentaje: 50),
    );

    expect(hecho.folio, 'AP-1791190000000');
    expect(backend.peticiones.map((p) => '${p.method} ${p.path}'), ['POST /carrito/pedidos', 'POST /apartados']);
    expect(cuerpo(0)['notas_cliente'], '(Apartado)');
    expect(cuerpo(0)['tipo_entrega'], 'tienda');
    expect(cuerpo(1), {'venta_id': 43, 'monto_abono_inicial': 580.32, 'metodo_pago_id': 2, 'plan_abono_id': 1});
  });

  test('Lee mis pedidos con sus piezas, la guía y el historial de estados', () async {
    final pedidos = await crear({
      'GET /carrito/pedidos/mis': {
        'success': true,
        'data': [_pedido],
      },
    }).misPedidos();

    final p = pedidos.single;
    expect(p.folio, 'DL-1791190000000');
    expect(p.estado, 'enviado');
    expect(p.total, 1360.64);
    expect(p.domicilio, isTrue);
    expect(p.totalPiezas, 2);
    expect(p.numeroGuia, '7712 4471 0098');
    expect(p.paqueteria, 'Estafeta');
    expect(p.fechaEstimada, isNotNull);
    expect(p.enCurso, isTrue);
    expect(p.historial.map((c) => c.estado), ['confirmado', 'en_preparacion', 'enviado']);
    expect(p.fechaDe('pendiente'), p.fechaCreacion);
    expect(p.fechaDe('enviado'), DateTime.parse('2026-10-07T17:05:00.000Z').toLocal());
    expect(p.fechaDe('entregado'), isNull);
  });

  test('Lee mis apartados con lo pagado, el saldo y la fecha límite', () async {
    final apartados = await crear({
      'GET /apartados/mis-apartados': {
        'success': true,
        'data': [
          {
            'id': 7,
            'folio': 'AP-1791190000000',
            'estado': 'activo',
            'monto_total': '1160.64',
            'monto_pagado': '580.32',
            'saldo_pendiente': '580.32',
            'fecha_limite_liquidacion': '2026-10-12T06:00:00.000Z',
            'plan_nombre': 'Semanal',
            'productos': [
              {'nombre': 'Anillos de plata ley .925', 'cantidad': 2, 'precio_unitario': '580.32', 'imagen': 'https://res.cloudinary.com/x/a.jpg'},
            ],
          },
        ],
      },
    }).misApartados();

    final a = apartados.single;
    expect(a.folio, 'AP-1791190000000');
    expect(a.saldo, 580.32);
    expect(a.avance, closeTo(.5, .001));
    expect(a.plan, 'Semanal');
    expect(a.activo, isTrue);
    expect(a.piezas.single.imagen, isNotNull);
  });

  test('Sin sesión avisa que hay que iniciarla', () async {
    final servicio = crear({}, status: 401);
    expect(servicio.misPedidos(), throwsA(isA<PedidoException>().having((e) => e.sinSesion, 'sinSesion', isTrue)));
  });

  test('Muestra el mensaje del backend cuando no hay existencias', () async {
    final servicio = crear({
      'POST /carrito/pedidos': {'success': false, 'message': 'Stock insuficiente para "Anillo halo". Solo quedan 1 unidades.'},
    }, status: 400);
    expect(
      servicio.comprar(
        metodo: const MetodoPago(id: 1, nombre: 'Transferencia', codigo: 'transferencia'),
      ),
      throwsA(isA<PedidoException>().having((e) => e.mensaje, 'mensaje', contains('Stock insuficiente'))),
    );
  });

  test('Sube el comprobante de transferencia en el campo "imagen"', () async {
    final servicio = crear({
      'POST /carrito/pedidos/43/comprobante': {'success': true, 'data': null},
    });
    await servicio.subirComprobante(43, [1, 2, 3], 'comprobante.jpg');

    final datos = backend.peticiones.single.data as FormData;
    expect(datos.files.single.key, 'imagen');
    expect(datos.files.single.value.filename, 'comprobante.jpg');
  });

  test('Lee el WhatsApp de la tienda solo con dígitos', () async {
    final servicio = crear({
      'GET /content/info-empresa': {
        'success': true,
        'data': {'whatsapp': '+52 771 332 1421'},
      },
    });
    expect(await servicio.whatsappTienda(), '527713321421');
  });

  test('Las fechas sin zona del backend se toman como UTC', () {
    final p = Pedido.fromJson({'id': 1, 'total': '10', 'fecha_creacion': '2026-10-05 21:13:57.862285'});
    expect(p.fechaCreacion, DateTime.utc(2026, 10, 5, 21, 13, 57, 862, 285).toLocal());
  });
}
