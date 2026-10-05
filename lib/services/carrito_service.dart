import 'package:dio/dio.dart';

import '../models/carrito.dart';
import 'api_client.dart';

class CarritoException implements Exception {
  const CarritoException(this.mensaje, {this.sinSesion = false});
  final String mensaje;
  // El backend respondió 401: hay que iniciar sesión para usar el carrito.
  final bool sinSesion;

  @override
  String toString() => mensaje;
}

// El carrito vive en el backend y va ligado a la cuenta del cliente,
// por eso es el mismo que ve en el sitio web. Todas las rutas piden sesión.
class CarritoService {
  CarritoService({required this._api});

  final ApiClient _api;

  Future<Carrito> obtener() async {
    final data = await _pedir(() => _api.dio.get('/carrito'));
    return Carrito.fromJson(data as Map<String, dynamic>);
  }

  Future<int> contar() async {
    final data = await _pedir(() => _api.dio.get('/carrito/count'));
    return (data as Map<String, dynamic>)['count'] as int? ?? 0;
  }

  // Si la pieza ya estaba, el backend suma la cantidad al mismo renglón.
  Future<void> agregar(int productoId, {int cantidad = 1, String? talla}) =>
      _pedir(() => _api.dio.post('/carrito', data: {'producto_id': productoId, 'cantidad': cantidad, 'talla_medida': ?talla}));

  Future<void> cambiarCantidad(int itemId, int cantidad) => _pedir(() => _api.dio.put('/carrito/$itemId', data: {'cantidad': cantidad}));

  Future<void> quitar(int itemId) => _pedir(() => _api.dio.delete('/carrito/$itemId'));

  Future<void> vaciar() => _pedir(() => _api.dio.delete('/carrito/vaciar'));

  Future<Object?> _pedir(Future<Response<dynamic>> Function() peticion) async {
    try {
      final respuesta = await peticion();
      final data = respuesta.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw CarritoException(data['message'] as String? ?? 'No se pudo actualizar tu carrito.');
      }
      return data['data'];
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const CarritoException('Inicia sesión para usar tu carrito.', sinSesion: true);
      }
      // 400 y 404 traen un mensaje entendible, por ejemplo "Stock insuficiente".
      final mensaje = switch (e.response?.data) {
        {'message': final String m} when status == 400 || status == 404 => m,
        _ => null,
      };
      throw CarritoException(mensaje ?? 'No se pudo cargar tu carrito. Revisa tu conexión e intenta de nuevo.');
    }
  }
}
