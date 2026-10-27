import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/carrito_provider.dart';
import 'providers/favoritos_provider.dart';
import 'providers/tema_provider.dart';
import 'routes/app_routes.dart';
import 'screens/abrir_pedido_screen.dart';
import 'services/avisos_pedido.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/carrito_service.dart';
import 'services/favorito_service.dart';
import 'services/notificaciones_service.dart';
import 'services/pedido_service.dart';
import 'services/perfil_service.dart';
import 'services/personalizacion_service.dart';
import 'services/producto_service.dart';
import 'services/service_factory.dart';
import 'services/session_storage.dart';

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
  final preferencia = SecurePreferenciaTema();
  final oscuro = await TemaProvider.leerInicial(preferencia);
  runApp(
    JoyeriaApp(
      storage: SecureSessionStorage(),
      mensajeria: conFirebase ? FirebaseMensajeria() : null,
      preferenciaTema: preferencia,
      temaOscuro: oscuro,
    ),
  );
  if (conFirebase) {
    // Avisos del pedido (#56). Se inicia después del primer cuadro para que ya exista el navegador
    // si la app se abrió desde un aviso.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AvisosPedido(
        fuente: FirebaseFuenteAvisos(),
        abrirPedido: abrirPedidoDesdeAviso,
      ).iniciar();
    });
  }
}

// Navegador de la app, para abrir un pedido al tocar su aviso desde fuera de una pantalla.
final navegadorApp = GlobalKey<NavigatorState>();

void abrirPedidoDesdeAviso(int pedidoId) {
  navegadorApp.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => AbrirPedidoScreen(pedidoId: pedidoId),
    ),
  );
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
    this.perfilService,
    this.preferenciaTema,
    this.temaOscuro = true,
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
  final PerfilService? perfilService;
  // Sin preferencia (pruebas), el tema se recuerda solo mientras la app está abierta.
  final PreferenciaTema? preferenciaTema;
  final bool temaOscuro;
  // Cliente del backend; las pruebas pasan uno con el backend simulado.
  final ApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    final api = apiClient ?? ApiClient(storage: storage);
    final fabrica = ServiceFactory(api);
    final carrito = carritoService ?? fabrica.crearCarritoService();
    final favoritos = favoritoService ?? fabrica.crearFavoritoService();
    final pedidos = pedidoService ?? fabrica.crearPedidoService();
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<ProductoService>.value(
          value: productoService ?? fabrica.crearProductoService(),
        ),
        Provider<CarritoService>.value(value: carrito),
        Provider<FavoritoService>.value(value: favoritos),
        Provider<PedidoService>.value(value: pedidos),
        Provider<PersonalizacionService>.value(
          value:
              personalizacionService ?? fabrica.crearPersonalizacionService(),
        ),
        Provider<PerfilService>.value(
          value:
              perfilService ??
              fabrica.crearPerfilService(
                pedidos: pedidos,
                favoritos: favoritos,
              ),
        ),
        ChangeNotifierProvider<FavoritosProvider>(
          create: (_) => FavoritosProvider(favoritos),
        ),
        ChangeNotifierProvider<CarritoProvider>(
          create: (_) => CarritoProvider(carrito),
        ),
        ChangeNotifierProvider<TemaProvider>(
          create: (_) => TemaProvider(
            preferenciaTema ?? MemoriaPreferenciaTema(),
            oscuro: temaOscuro,
          ),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            authService ?? fabrica.crearAuthService(storage),
            notificaciones: mensajeria == null
                ? null
                : NotificacionesService(api: api, mensajeria: mensajeria!),
          )..restaurarSesion(),
        ),
      ],
      child: Consumer<TemaProvider>(
        builder: (context, tema, _) => MaterialApp(
          title: 'Joyería Diana Laura',
          debugShowCheckedModeBanner: false,
          navigatorKey: navegadorApp,
          theme: tema.tema,
          // Sin animación entre temas: los colores fijos y los del tema cambian a la vez.
          themeAnimationDuration: Duration.zero,
          builder: (context, child) =>
              ReconstruirConTema(oscuro: tema.oscuro, child: child!),
          initialRoute: AppRoutes.home,
          routes: AppRoutes.routes,
        ),
      ),
    );
  }
}
