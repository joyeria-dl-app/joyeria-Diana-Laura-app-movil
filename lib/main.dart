import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'routes/app_routes.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/carrito_service.dart';
import 'services/producto_service.dart';
import 'services/session_storage.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(JoyeriaApp(storage: SecureSessionStorage()));
}

class JoyeriaApp extends StatelessWidget {
  const JoyeriaApp({super.key, required this.storage, this.authService, this.productoService, this.carritoService});

  final SessionStorage storage;
  final AuthService? authService;
  final ProductoService? productoService;
  final CarritoService? carritoService;

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(storage: storage);
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<ProductoService>.value(value: productoService ?? ProductoService(api: api)),
        Provider<CarritoService>.value(value: carritoService ?? CarritoService(api: api)),
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
