import 'package:dio/dio.dart';

import '../models/producto.dart';
import 'api_client.dart';

class FavoritoException implements Exception {
  const FavoritoException(this.mensaje, {this.sinSesion = false});
  final String mensaje;
  // El backend respondió 401: hay que iniciar sesión para guardar favoritos.
  final bool sinSesion;

  @override
  String toString() => mensaje;
}

// Los favoritos van ligados a la cuenta del cliente, por eso son los mismos
// que ve en el sitio web. Todas las rutas piden sesión.
class FavoritoService {
  FavoritoService({required this._api});

  final ApiClient _api;

  // Del más reciente al más antiguo; el backend ya omite las piezas desactivadas.
  Future<List<Producto>> lista() async {
    final data = await _pedir(() => _api.dio.get('/favoritos'));
    return (data['data'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        // Cada renglón trae el id del favorito; el de la pieza viene en producto_id.
        .map((f) => Producto.fromJson({...f, 'id': f['producto_id']}))
        .toList();
  }

  Future<bool> esFavorito(int productoId) async {
    final data = await _pedir(() => _api.dio.get('/favoritos/check/$productoId'));
    return data['favorito'] == true;
  }

  // Si la pieza ya era favorita la quita, si no la guarda. Devuelve cómo quedó.
  Future<bool> alternar(int productoId) async {
    final data = await _pedir(() => _api.dio.post('/favoritos/toggle', data: {'producto_id': productoId}));
    return data['favorito'] == true;
  }

  Future<Map<String, dynamic>> _pedir(Future<Response<dynamic>> Function() peticion) async {
    try {
      final data = (await peticion()).data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw FavoritoException(data['message'] as String? ?? 'No se pudieron actualizar tus favoritos.');
      }
      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw const FavoritoException('Inicia sesión para guardar tus favoritos.', sinSesion: true);
      }
      throw const FavoritoException('No se pudieron cargar tus favoritos. Revisa tu conexión e intenta de nuevo.');
    }
  }
}
