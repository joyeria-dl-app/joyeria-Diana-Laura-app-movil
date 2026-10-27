import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/carrito_provider.dart';
import 'providers/favoritos_provider.dart';
import 'providers/tema_provider.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferencia = SecurePreferenciaTema();
  final oscuro = await TemaProvider.leerInicial(preferencia);
  runApp(JoyeriaApp(storage: SecureSessionStorage(), preferenciaTema: preferencia, temaOscuro: oscuro));
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
    this.preferenciaTema,
    this.temaOscuro = true,
  });

  final SessionStorage storage;
  final AuthService? authService;
  final ProductoService? productoService;
  final CarritoService? carritoService;
  final FavoritoService? favoritoService;
  final PedidoService? pedidoService;
  final PersonalizacionService? personalizacionService;
  final PerfilService? perfilService;
  // Sin preferencia (pruebas), el tema se recuerda solo mientras la app está abierta.
  final PreferenciaTema? preferenciaTema;
  final bool temaOscuro;

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
        ChangeNotifierProvider<TemaProvider>(create: (_) => TemaProvider(preferenciaTema ?? MemoriaPreferenciaTema(), oscuro: temaOscuro)),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(authService ?? fabrica.crearAuthService(storage))..restaurarSesion()),
      ],
      child: Consumer<TemaProvider>(
        builder: (context, tema, _) => MaterialApp(
          title: 'Joyería Diana Laura',
          debugShowCheckedModeBanner: false,
          theme: tema.tema,
          // Sin animación entre temas: los colores fijos y los del tema cambian a la vez.
          themeAnimationDuration: Duration.zero,
          builder: (context, child) => ReconstruirConTema(oscuro: tema.oscuro, child: child!),
          initialRoute: AppRoutes.home,
          routes: AppRoutes.routes,
        ),
      ),
    );
  }
}
