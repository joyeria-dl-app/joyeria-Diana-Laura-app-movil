import 'package:dio/dio.dart';

import '../models/pedido.dart';
import 'api_client.dart';

class PedidoException implements Exception {
  const PedidoException(this.mensaje, {this.sinSesion = false});
  final String mensaje;
  // El backend respondió 401: hay que iniciar sesión.
  final bool sinSesion;

  @override
  String toString() => mensaje;
}

// Pedidos y apartados del cliente (HU-11). Usa los mismos endpoints que el sitio
// web, así que lo que se confirma en la app aparece en "Mis pedidos" de la web.
class PedidoService {
  PedidoService({required this._api});

  final ApiClient _api;

  // Métodos de pago activos y costo del envío a domicilio.
  Future<OpcionesCompra> opciones() async {
    final data = await _pedir(() => _api.dio.get('/carrito/metodos-pago'));
    return OpcionesCompra.fromJson(data as Map<String, dynamic>);
  }

  // Lugares donde la tienda entrega a domicilio.
  Future<List<String>> zonas() async {
    final data = await _pedir(() => _api.dio.get('/zonas-entrega'));
    return (data as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((z) => z['activo'] != false)
        .map((z) => z['nombre'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  Future<List<PlanAbono>> planes() async {
    final data = await _pedir(() => _api.dio.get('/apartados/planes'));
    return (data as List<dynamic>).cast<Map<String, dynamic>>().where((p) => p['activo'] != false).map(PlanAbono.fromJson).toList();
  }

  // Compra con lo que hay en el carrito; el backend vacía el carrito al crear el pedido.
  Future<Confirmacion> comprar({required MetodoPago metodo, DireccionEntrega? direccion, double costoEnvio = 0, String? notas}) async {
    final domicilio = direccion != null;
    final data = await _pedir(
      () => _api.dio.post(
        '/carrito/pedidos',
        data: {
          'direccion_envio': domicilio ? direccion.texto : 'Recoger en tienda',
          'notas_cliente': notas ?? '',
          'metodo_pago_id': metodo.id,
          'tipo_entrega': domicilio ? 'domicilio' : 'tienda',
          'costo_envio': domicilio ? costoEnvio : 0,
          'direccion_data': domicilio ? direccion.toJson() : null,
        },
      ),
    );
    final venta = data as Map<String, dynamic>;
    return Confirmacion(folio: venta['folio'] as String? ?? '#${venta['id']}', pedidoId: venta['id'] as int);
  }

  // Igual que el sitio web: primero se crea el pedido para recoger en tienda y
  // luego el apartado sobre ese pedido con el abono de hoy (mínimo 50%).
  Future<Confirmacion> apartar({required MetodoPago metodo, required double abonoHoy, PlanAbono? plan}) async {
    final venta = await _pedir(
      () => _api.dio.post(
        '/carrito/pedidos',
        data: {
          'direccion_envio': 'Recoger en tienda',
          'notas_cliente': '(Apartado)',
          'metodo_pago_id': metodo.id,
          'tipo_entrega': 'tienda',
          'costo_envio': 0,
          'direccion_data': null,
        },
      ),
    ) as Map<String, dynamic>;
    final data = await _pedir(
      () => _api.dio.post(
        '/apartados',
        data: {'venta_id': venta['id'], 'monto_abono_inicial': abonoHoy, 'metodo_pago_id': metodo.id, 'plan_abono_id': ?plan?.id},
      ),
    ) as Map<String, dynamic>;
    return Confirmacion(folio: data['folio'] as String? ?? '#${venta['id']}', pedidoId: venta['id'] as int);
  }

  Future<List<Pedido>> misPedidos() async {
    final data = await _pedir(() => _api.dio.get('/carrito/pedidos/mis'));
    return (data as List<dynamic>).cast<Map<String, dynamic>>().map(Pedido.fromJson).toList();
  }

  // Comprobante de transferencia (POST /carrito/pedidos/:id/comprobante, campo "imagen").
  Future<void> subirComprobante(int pedidoId, List<int> bytes, String nombreArchivo) async {
    await _pedir(
      () =>
          _api.dio.post('/carrito/pedidos/$pedidoId/comprobante', data: FormData.fromMap({'imagen': MultipartFile.fromBytes(bytes, filename: nombreArchivo)})),
    );
  }

  // Abono a un apartado, igual que en el sitio web (POST /apartados/:id/solicitar-abono).
  // Con transferencia se manda la foto del comprobante en el campo "imagen"; el trabajador lo confirma.
  Future<void> solicitarAbono(int apartadoId, {required double monto, required MetodoPago metodo, List<int>? comprobante, String? nombreArchivo}) async {
    final datos = {'monto': monto.toStringAsFixed(2), 'metodo_pago_id': metodo.id};
    await _pedir(
      () => _api.dio.post(
        '/apartados/$apartadoId/solicitar-abono',
        data: comprobante == null
            ? datos
            : FormData.fromMap({...datos, 'imagen': MultipartFile.fromBytes(comprobante, filename: nombreArchivo ?? 'comprobante.jpg')}),
      ),
    );
  }

  // WhatsApp de la tienda dado de alta en el panel (por ejemplo "527713321421").
  Future<String?> whatsappTienda() async {
    final data = await _pedir(() => _api.dio.get('/content/info-empresa'));
    final numero = ((data as Map<String, dynamic>)['whatsapp'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
    return numero.isEmpty ? null : numero;
  }

  Future<List<Apartado>> misApartados() async {
    final data = await _pedir(() => _api.dio.get('/apartados/mis-apartados'));
    return (data as List<dynamic>).cast<Map<String, dynamic>>().map(Apartado.fromJson).toList();
  }

  Future<Object?> _pedir(Future<Response<dynamic>> Function() peticion) async {
    try {
      final respuesta = await peticion();
      final data = respuesta.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw PedidoException(data['message'] as String? ?? 'No se pudo completar tu pedido.');
      }
      return data['data'];
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const PedidoException('Inicia sesión para ver y hacer tus pedidos.', sinSesion: true);
      }
      // 400 y 404 traen un mensaje entendible, por ejemplo "Stock insuficiente…".
      final mensaje = switch (e.response?.data) {
        {'message': final String m} when status == 400 || status == 404 => m,
        _ => null,
      };
      throw PedidoException(mensaje ?? 'No se pudo conectar. Revisa tu conexión e intenta de nuevo.');
    }
  }
}
