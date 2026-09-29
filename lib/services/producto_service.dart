import 'package:dio/dio.dart';

import '../models/producto.dart';
import 'api_client.dart';

class ProductoException implements Exception {
  const ProductoException(this.mensaje);
  final String mensaje;

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

  Future<List<dynamic>> _obtener(String ruta, [Map<String, dynamic>? parametros]) async {
    try {
      final respuesta = await _api.dio.get(ruta, queryParameters: parametros);
      final data = respuesta.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ProductoException(data['message'] as String? ?? 'No se pudo cargar el catálogo.');
      }
      return data['data'] as List<dynamic>;
    } on DioException {
      throw const ProductoException('No se pudo cargar el catálogo. Revisa tu conexión e intenta de nuevo.');
    }
  }
}
