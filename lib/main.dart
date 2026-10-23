import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/carrito_provider.dart';
import 'providers/favoritos_provider.dart';
import 'routes/app_routes.dart';
import 'screens/abrir_pedido_screen.dart';
import 'services/avisos_pedido.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/carrito_service.dart';
import 'services/favorito_service.dart';
import 'services/notificaciones_service.dart';
import 'services/pedido_service.dart';
import 'services/personalizacion_service.dart';
import 'services/producto_service.dart';
import 'services/session_storage.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase Cloud Messaging para los avisos del pedido (#55). Si no arranca, la app funciona sin avisos.
  var conFirebase = true;
  try {
    await Firebase.initializeApp();
  } on Object catch (e) {
    conFirebase = false;
    debugPrint('Firebase no se inició: $e');
  }
  runApp(JoyeriaApp(storage: SecureSessionStorage(), mensajeria: conFirebase ? FirebaseMensajeria() : null));
  if (conFirebase) {
    // Avisos del pedido (#56). Se inicia después del primer cuadro para que ya exista el navegador
    // si la app se abrió desde un aviso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AvisosPedido(fuente: FirebaseFuenteAvisos(), abrirPedido: abrirPedidoDesdeAviso).iniciar();
    });
  }
}

// Navegador de la app, para abrir un pedido al tocar su aviso desde fuera de una pantalla.
final navegadorApp = GlobalKey<NavigatorState>();

void abrirPedidoDesdeAviso(int pedidoId) {
  navegadorApp.currentState?.push(MaterialPageRoute<void>(builder: (_) => AbrirPedidoScreen(pedidoId: pedidoId)));
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
    this.mensajeria,
    this.apiClient,
  });

  final SessionStorage storage;
  final AuthService? authService;
  final ProductoService? productoService;
  final CarritoService? carritoService;
  final FavoritoService? favoritoService;
  final PedidoService? pedidoService;
  final PersonalizacionService? personalizacionService;
  // Sin mensajería (pruebas o Firebase sin iniciar) la app no registra el teléfono para avisos.
  final MensajeriaPush? mensajeria;
  // Cliente del backend; las pruebas pasan uno con el backend simulado.
  final ApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    final api = apiClient ?? ApiClient(storage: storage);
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
        ChangeNotifierProvider<FavoritosProvider>(create: (_) => FavoritosProvider(favoritos)),
        ChangeNotifierProvider<CarritoProvider>(create: (_) => CarritoProvider(carrito)),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            authService ?? AuthService(api: api, storage: storage),
            notificaciones: mensajeria == null ? null : NotificacionesService(api: api, mensajeria: mensajeria!),
          )..restaurarSesion(),
        ),
      ],
      child: MaterialApp(
        title: 'Joyería Diana Laura',
        debugShowCheckedModeBanner: false,
        navigatorKey: navegadorApp,
        theme: AppTheme.oscuro(),
        initialRoute: AppRoutes.home,
        routes: AppRoutes.routes,
      ),
    );
  }
}
