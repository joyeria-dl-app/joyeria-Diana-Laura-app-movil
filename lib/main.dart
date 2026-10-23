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
import 'services/personalizacion_service.dart';
import 'services/producto_service.dart';
import 'services/session_storage.dart';
import 'services/zonas_service.dart';
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
    this.zonasService,
  });

  final SessionStorage storage;
  final AuthService? authService;
  final ProductoService? productoService;
  final CarritoService? carritoService;
  final FavoritoService? favoritoService;
  final PedidoService? pedidoService;
  final PersonalizacionService? personalizacionService;
  final ZonasService? zonasService;

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(storage: storage);
    final carrito = carritoService ?? CarritoService(api: api);
    final favoritos = favoritoService ?? FavoritoService(api: api);
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<ProductoService>.value(value: productoService ?? ProductoService(api: api)),
        Provider<CarritoService>.value(value: carrito),
        Provider<FavoritoService>.value(value: favoritos),
        Provider<PedidoService>.value(value: pedidoService ?? PedidoService(api: api)),
        Provider<PersonalizacionService>.value(value: personalizacionService ?? PersonalizacionService(api: api)),
        Provider<ZonasService>.value(value: zonasService ?? ZonasService(api: api)),
        ChangeNotifierProvider<FavoritosProvider>(create: (_) => FavoritosProvider(favoritos)),
        ChangeNotifierProvider<CarritoProvider>(create: (_) => CarritoProvider(carrito)),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authService ?? AuthService(api: api, storage: storage))..restaurarSesion(),
        ),
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
