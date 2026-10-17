import 'package:dio/dio.dart';

import '../models/perfil.dart';
import 'api_client.dart';
import 'favorito_service.dart';
import 'pedido_service.dart';

class PerfilException implements Exception {
  const PerfilException(this.mensaje, {this.sinSesion = false});
  final String mensaje;
  // El backend respondió 401: hay que iniciar sesión.
  final bool sinSesion;

  @override
  String toString() => mensaje;
}

// Mi perfil (HU-14): la cuenta del cliente y lo que lleva en la tienda.
class PerfilService {
  PerfilService({required this._api, required this._pedidos, required this._favoritos});

  final ApiClient _api;
  final PedidoService _pedidos;
  final FavoritoService _favoritos;

  // GET /auth/profile: nombre, correo, teléfono, foto y fecha de registro.
  Future<Perfil> perfil() async {
    try {
      final data = (await _api.dio.get('/auth/profile')).data as Map<String, dynamic>;
      if (data['success'] != true) throw PerfilException(data['message'] as String? ?? 'No se pudo cargar tu perfil.');
      return Perfil.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) throw const PerfilException('Inicia sesión para ver tu perfil.', sinSesion: true);
      throw const PerfilException('No se pudo conectar. Revisa tu conexión e intenta de nuevo.');
    }
  }

  // Pedidos, apartados y favoritos del cliente. Cada número se pide por su lado: si uno
  // falla, los otros se muestran igual.
  Future<ResumenCliente> resumen() async {
    Future<int?> contar(Future<List<Object>> Function() lista) async {
      try {
        return (await lista()).length;
      } on Object {
        return null;
      }
    }

    final r = await Future.wait([contar(_pedidos.misPedidos), contar(_pedidos.misApartados), contar(_favoritos.lista)]);
    return ResumenCliente(pedidos: r[0], apartados: r[1], favoritos: r[2]);
  }
}
