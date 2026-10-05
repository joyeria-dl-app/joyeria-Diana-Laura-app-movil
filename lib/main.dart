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
import 'services/producto_service.dart';
import 'services/session_storage.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(JoyeriaApp(storage: SecureSessionStorage()));
}

class JoyeriaApp extends StatelessWidget {
  const JoyeriaApp({super.key, required this.storage, this.authService, this.productoService, this.carritoService, this.favoritoService});

  final SessionStorage storage;
  final AuthService? authService;
  final ProductoService? productoService;
  final CarritoService? carritoService;
  final FavoritoService? favoritoService;

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
