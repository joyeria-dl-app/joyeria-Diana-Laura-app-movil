import 'package:dio/dio.dart';

import '../models/producto.dart';
import 'api_client.dart';

class ProductoException implements Exception {
  const ProductoException(this.mensaje, {this.noEncontrado = false});
  final String mensaje;
  // La pieza no existe o se desactivó; no sirve reintentar.
  final bool noEncontrado;

  @override
  String toString() => mensaje;
}

// El catálogo es público: estas rutas no necesitan sesión.
class ProductoService {
  ProductoService({required this._api});

  final ApiClient _api;

  static const int porPagina = 20;

  // Listado del catálogo. `categoriaId` filtra por categoría y `pagina`
  // (desde 0) permite cargar más productos al llegar al final de la lista.
  Future<List<Producto>> productos({int? categoriaId, String? busqueda, int pagina = 0}) async {
    final lista = await _obtener('/products/filter', {
      'limit': porPagina,
      'offset': pagina * porPagina,
      'categoria_id': ?categoriaId,
      if (busqueda != null && busqueda.trim().isNotEmpty) 'nombre': busqueda.trim(),
    });
    return lista.map((p) => Producto.fromJson(p as Map<String, dynamic>)).toList();
  }

  // El backend también devuelve las categorías desactivadas desde el panel.
  Future<List<Categoria>> categorias() async {
    final lista = await _obtener('/products/categorias');
    return lista
        .cast<Map<String, dynamic>>()
        .where((c) => c['activo'] == true && c['categoria_padre_id'] == null)
        .map(Categoria.fromJson)
        .toList();
  }

  // Detalle de una pieza con su galería de imágenes.
  Future<DetalleProducto> detalle(int id) async {
    final data = await _pedir('/products/$id', noEncontrado: 'Esta pieza ya no está disponible.');
    return DetalleProducto.fromJson(data as Map<String, dynamic>);
  }

  Future<List<dynamic>> _obtener(String ruta, [Map<String, dynamic>? parametros]) async =>
      await _pedir(ruta, parametros: parametros) as List<dynamic>;

  Future<Object?> _pedir(String ruta, {Map<String, dynamic>? parametros, String? noEncontrado}) async {
    try {
      final respuesta = await _api.dio.get(ruta, queryParameters: parametros);
      final data = respuesta.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ProductoException(data['message'] as String? ?? 'No se pudo cargar el catálogo.');
      }
      return data['data'];
    } on DioException catch (e) {
      // El backend responde 404 si la pieza no existe o se desactivó.
      if (noEncontrado != null && e.response?.statusCode == 404) throw ProductoException(noEncontrado, noEncontrado: true);
      throw const ProductoException('No se pudo cargar el catálogo. Revisa tu conexión e intenta de nuevo.');
    }
  }
}
