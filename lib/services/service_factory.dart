import 'api_client.dart';
import 'auth_service.dart';
import 'carrito_service.dart';
import 'favorito_service.dart';
import 'pedido_service.dart';
import 'perfil_service.dart';
import 'personalizacion_service.dart';
import 'producto_service.dart';
import 'session_storage.dart';

// Patrón Factory: un solo lugar decide cómo se crean los servicios que usan el ApiClient.
class ServiceFactory {
  ServiceFactory(this._api);

  final ApiClient _api;

  AuthService crearAuthService(SessionStorage storage) => AuthService(api: _api, storage: storage);
  ProductoService crearProductoService() => ProductoService(api: _api);
  CarritoService crearCarritoService() => CarritoService(api: _api);
  FavoritoService crearFavoritoService() => FavoritoService(api: _api);
  PedidoService crearPedidoService() => PedidoService(api: _api);
  PersonalizacionService crearPersonalizacionService() => PersonalizacionService(api: _api);
  PerfilService crearPerfilService({required PedidoService pedidos, required FavoritoService favoritos}) =>
      PerfilService(api: _api, pedidos: pedidos, favoritos: favoritos);
}
