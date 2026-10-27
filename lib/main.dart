import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/carrito_provider.dart';
import 'providers/favoritos_provider.dart';
import 'routes/app_routes.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/carrito_service.dart';
import 'services/favorito_service.dart';
import 'services/pedido_service.dart';
import 'services/perfil_service.dart';
import 'services/personalizacion_service.dart';
import 'services/producto_service.dart';
import 'services/service_factory.dart';
import 'services/session_storage.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(JoyeriaApp(storage: SecureSessionStorage()));
}

class JoyeriaApp extends StatelessWidget {
  const JoyeriaApp({
    super.key,
    required this.storage,
    this.authService,
    this.productoService,
    this.carritoService,
    this.favoritoService,
    this.pedidoService,
    this.personalizacionService,
    this.perfilService,
  });

  final SessionStorage storage;
  final AuthService? authService;
  final ProductoService? productoService;
  final CarritoService? carritoService;
  final FavoritoService? favoritoService;
  final PedidoService? pedidoService;
  final PersonalizacionService? personalizacionService;
  final PerfilService? perfilService;

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(storage: storage);
    final fabrica = ServiceFactory(api);
    final carrito = carritoService ?? fabrica.crearCarritoService();
    final favoritos = favoritoService ?? fabrica.crearFavoritoService();
    final pedidos = pedidoService ?? fabrica.crearPedidoService();
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<ProductoService>.value(value: productoService ?? fabrica.crearProductoService()),
        Provider<CarritoService>.value(value: carrito),
        Provider<FavoritoService>.value(value: favoritos),
        Provider<PedidoService>.value(value: pedidos),
        Provider<PersonalizacionService>.value(value: personalizacionService ?? fabrica.crearPersonalizacionService()),
        Provider<PerfilService>.value(
          value: perfilService ?? fabrica.crearPerfilService(pedidos: pedidos, favoritos: favoritos),
        ),
        ChangeNotifierProvider<FavoritosProvider>(create: (_) => FavoritosProvider(favoritos)),
        ChangeNotifierProvider<CarritoProvider>(create: (_) => CarritoProvider(carrito)),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(authService ?? fabrica.crearAuthService(storage))..restaurarSesion()),
      ],
      child: MaterialApp(
        title: 'Joyería Diana Laura',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.oscuro(),
        initialRoute: AppRoutes.home,
        routes: AppRoutes.routes,
      ),
    );
  }
}
