// TIPO: seguridad
// ALCANCE: HU-19 · casos SP-01 a SP-12: el backend rechaza pagos, montos y accesos alterados (#98)
// EJECUCIÓN: A MANO, en el emulador: crea un pedido real. flutter test integration_test/seguridad_pago_test.dart --dart-define-from-file=env.json
// DATOS: integration_test/datos_prueba.dart (cuenta de env.json o de los secretos); registros de otra cuenta de datos_prueba.dart; el pedido de prueba se cancela al terminar

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/main.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';

import 'catalogo_test.dart' show despertarServidor;
import 'sesion.dart';
import 'datos_prueba.dart';

// Pruebas de seguridad del pago (HU-19, #98). Una app modificada puede mandar al backend lo
// que quiera; aquí se inicia sesión con la cuenta de prueba y, con el mismo cliente HTTP de
// la app, se mandan peticiones alteradas: pagar pedidos ajenos, cambiar montos y precios,
// marcar pagos sin pagar y avisos falsos de Mercado Pago y PayPal. El backend debe
// rechazarlas y el pedido no debe cambiar. Resultados en pruebas/seguridad_pago_sprint3.md.
//
// Crea un pedido real de la cuenta de prueba que después se cancela en la base de datos.

void _caso(String id, String descripcion) => debugPrint('SEGURIDAD $id Pasa: $descripcion');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(despertarServidor);

  testWidgets('Seguridad del pago: el backend rechaza peticiones alteradas', (tester) async {
    expect(CuentaPrueba.correo, isNotEmpty, reason: 'Falta PRUEBAS_CORREO');
    expect(CuentaPrueba.contrasena, isNotEmpty, reason: 'Falta PRUEBAS_CONTRASENA');

    await tester.pumpWidget(JoyeriaApp(storage: SecureSessionStorage()));
    await iniciarSesion(tester, CuentaPrueba.correo, CuentaPrueba.contrasena);

    final contexto = tester.element(find.byType(Scaffold).first);
    final dio = contexto.read<ApiClient>().dio;
    // Mismo servidor, sin sesión: lo que haría alguien sin cuenta.
    final sinSesion = Dio(BaseOptions(baseUrl: dio.options.baseUrl, headers: {'Content-Type': 'application/json'}));

    // Código HTTP de la respuesta, sea éxito o error.
    Future<int> codigo(Future<Response<dynamic>> Function() peticion) async => (await tester.runAsync(() async {
      try {
        return (await peticion()).statusCode ?? 0;
      } on DioException catch (e) {
        return e.response?.statusCode ?? 0;
      }
    }))!;

    Future<Map<String, dynamic>> datos(Future<Response<dynamic>> Function() peticion) async =>
        ((await tester.runAsync(peticion))!.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;

    void rechazada(int estado, String que) => expect(estado, inInclusiveRange(400, 499), reason: '$que debió rechazarse y respondió $estado');

    // Pedido propio de prueba: precio y envío alterados en lo que manda la app.
    final pieza = (await tester.runAsync(() => contexto.read<ProductoService>().detalle(PiezasPrueba.pedidoSeguridad)))!.producto;
    final metodos = (await datos(() => dio.get('/carrito/metodos-pago')));
    final mp = (metodos['metodos'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>().firstWhere(
      (m) => m['codigo'] == 'mercadopago',
      orElse: () => fail('No hay método Mercado Pago activo: $metodos'),
    );
    await codigo(() => dio.delete('/carrito/vaciar'));

    // SP-01: agregar al carrito con un precio inventado; el carrito usa el precio del catálogo.
    expect(
      await codigo(() => dio.post('/carrito', data: {'producto_id': PiezasPrueba.pedidoSeguridad, 'cantidad': 1, 'precio_venta': 1, 'precio_unitario': 1})),
      inInclusiveRange(200, 201),
    );
    final carrito = (await tester.runAsync(() => dio.get('/carrito')))!.data as Map<String, dynamic>;
    final renglon = ((carrito['data'] as Map<String, dynamic>)['items'] as List<dynamic>).cast<Map<String, dynamic>>().single;
    expect(double.parse('${renglon['precio_venta']}'), pieza.precioVenta);
    _caso('SP-01', 'precio inventado al agregar al carrito: se usa el del catálogo (\$${pieza.precioVenta})');

    // SP-02: cantidades fuera de rango.
    for (final cantidad in [0, -3, 100000]) {
      rechazada(await codigo(() => dio.post('/carrito', data: {'producto_id': PiezasPrueba.pedidoSeguridad, 'cantidad': cantidad})), 'cantidad $cantidad');
    }
    _caso('SP-02', 'cantidades 0, -3 y 100000 rechazadas');

    // SP-03: pedido a domicilio con costo de envío 0 en lo que manda la app; el servidor pone el suyo.
    final pedido = await datos(
      () => dio.post(
        '/carrito/pedidos',
        data: {
          'direccion_envio': 'Prueba de seguridad #98 (se cancela)',
          'notas_cliente': 'Prueba de seguridad #98',
          'metodo_pago_id': mp['id'],
          'tipo_entrega': 'domicilio',
          'costo_envio': 0,
          'total': 1,
        },
      ),
    );
    final pedidoId = pedido['id'] as int;
    final envio = double.parse('${pedido['costo_envio']}');
    final total = double.parse('${pedido['total']}');
    expect(envio, greaterThan(0));
    expect(total, closeTo(pieza.precioVenta + envio, 0.01));
    debugPrint('SEGURIDAD PEDIDO $pedidoId');
    _caso('SP-03', 'pedido $pedidoId con envío 0 y total 1 en la petición: el servidor cobra envío \$$envio y total \$$total');

    // SP-04: pagar con Mercado Pago un pedido que la tienda no ha confirmado.
    rechazada(await codigo(() => dio.post('/carrito/pago/mercadopago', data: {'venta_id': pedidoId, 'origen': 'app'})), 'preferencia sin confirmar');
    _caso('SP-04', 'no da enlace de Mercado Pago para un pedido sin confirmar');

    // SP-05: apartado con abono menor al 50%, mayor al total o que no es número.
    for (final abono in [total * 0.2, total * 2, 'abc', -10]) {
      rechazada(
        await codigo(() => dio.post('/apartados', data: {'venta_id': pedidoId, 'monto_abono_inicial': abono, 'metodo_pago_id': mp['id']})),
        'abono $abono',
      );
    }
    _caso('SP-05', 'abonos de 20%, 200%, "abc" y -10 rechazados');

    // SP-06: el pedido y el apartado de otra cuenta.
    rechazada(await codigo(() => dio.get('/carrito/pedidos/${RegistrosAjenos.pedido}')), 'ver pedido ajeno');
    rechazada(await codigo(() => dio.post('/carrito/pago/mercadopago', data: {'venta_id': RegistrosAjenos.pedido})), 'pagar pedido ajeno con MP');
    rechazada(await codigo(() => dio.post('/carrito/pago/paypal/crear', data: {'venta_id': RegistrosAjenos.pedido})), 'pagar pedido ajeno con PayPal');
    rechazada(await codigo(() => dio.post('/apartados/pago/mercadopago', data: {'apartado_id': RegistrosAjenos.apartado})), 'pagar apartado ajeno');
    rechazada(await codigo(() => dio.post('/apartados/pago/mercadopago/abono', data: {'abono_id': RegistrosAjenos.abono})), 'pagar abono ajeno');
    _caso(
      'SP-06',
      'no deja ver ni pagar el pedido ${RegistrosAjenos.pedido}, el apartado ${RegistrosAjenos.apartado} ni el abono ${RegistrosAjenos.abono} de otra cuenta',
    );

    // SP-12 (#216): ver el detalle de un apartado ajeno. Antes de la corrección del backend
    // respondía 200 con las piezas, los abonos y el comprobante de otra clienta.
    rechazada(await codigo(() => dio.get('/apartados/${RegistrosAjenos.apartado}')), 'ver apartado ajeno');
    _caso('SP-12', 'no deja ver el detalle del apartado ${RegistrosAjenos.apartado} de otra cuenta');

    // SP-07: acciones del personal hechas por el cliente.
    rechazada(await codigo(() => dio.patch('/carrito/pedidos/$pedidoId/estado', data: {'estado': 'entregado'})), 'cambiar estado');
    rechazada(await codigo(() => dio.post('/carrito/pedidos/$pedidoId/confirmar-pago-efectivo')), 'confirmar pago en efectivo');
    rechazada(await codigo(() => dio.post('/apartados/${RegistrosAjenos.apartado}/confirmar-pago')), 'confirmar pago de apartado');
    _caso('SP-07', 'el cliente no puede marcar su pedido entregado ni confirmar pagos');

    // SP-08: aviso falso de Mercado Pago con un pago que no existe y la referencia del pedido.
    await codigo(
      () => sinSesion.post(
        '/carrito/webhook/mercadopago',
        data: {
          'type': 'payment',
          'data': {'id': '999999999999'},
          'external_reference': '$pedidoId',
          'status': 'approved',
        },
      ),
    );
    await codigo(
      () => sinSesion.post(
        '/apartados/webhook/mercadopago',
        data: {
          'type': 'payment',
          'data': {'id': '999999999998'},
          'status': 'approved',
        },
      ),
    );
    // SP-09: captura falsa de PayPal.
    rechazada(
      await codigo(() => dio.post('/carrito/pago/paypal/capturar', data: {'order_id': 'ORDEN-FALSA-98', 'venta_id': pedidoId})),
      'captura PayPal falsa',
    );
    final despues = await datos(() => dio.get('/carrito/pedidos/$pedidoId'));
    expect(despues['estado_pago'], isNot('aprobado'));
    expect(despues['estado'], 'pendiente');
    _caso('SP-08', 'los avisos falsos de Mercado Pago no marcan el pedido como pagado (estado_pago: ${despues['estado_pago']})');
    _caso('SP-09', 'una captura de PayPal con una orden inventada se rechaza y el pedido sigue sin pagar');

    // SP-10: sin sesión no se puede pedir enlace de pago ni crear pedidos.
    expect(await codigo(() => sinSesion.post('/carrito/pago/mercadopago', data: {'venta_id': pedidoId})), 401);
    expect(await codigo(() => sinSesion.post('/carrito/pedidos', data: {'direccion_envio': 'x', 'metodo_pago_id': mp['id']})), 401);
    expect(await codigo(() => sinSesion.get('/carrito/pedidos/$pedidoId/recibo')), 401);
    _caso('SP-10', 'sin sesión: enlace de pago, pedido y recibo responden 401');

    // SP-11: token inventado.
    final falso = Dio(BaseOptions(baseUrl: dio.options.baseUrl, headers: {'Authorization': 'Bearer eyJhbGciOiJIUzI1NiJ9.e30.firma-falsa'}));
    expect(await codigo(() => falso.post('/carrito/pago/mercadopago', data: {'venta_id': pedidoId})), anyOf(401, 403));
    expect(await codigo(() => falso.get('/carrito/pedidos/$pedidoId/recibo?token=token-falso')), anyOf(401, 403));
    _caso('SP-11', 'con un token inventado el backend rechaza la petición (401/403)');

    await codigo(() => dio.delete('/carrito/vaciar'));
    debugPrint('SEGURIDAD PASO cancelar $pedidoId');
  });
}
