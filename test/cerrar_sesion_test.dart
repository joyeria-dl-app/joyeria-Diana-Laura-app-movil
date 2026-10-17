// TIPO: widget
// ALCANCE: HU-14 · cerrar sesión (#52): confirmación, sesión borrada, carrito y favoritos olvidados y regreso al inicio
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/cerrar_sesion_test.dart
// DATOS: backend simulado en memoria (sin red); cuenta, carrito y favoritos de ejemplo

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/carrito.dart';
import 'package:joyeria_diana_laura/models/perfil.dart';
import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/models/usuario.dart';
import 'package:joyeria_diana_laura/providers/auth_provider.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/providers/favoritos_provider.dart';
import 'package:joyeria_diana_laura/screens/perfil_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/auth_service.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/services/pedido_service.dart';
import 'package:joyeria_diana_laura/services/perfil_service.dart';
import 'package:joyeria_diana_laura/services/session_storage.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

const _ana = Usuario(email: 'ana.martinez@correo.com', nombre: 'Ana Martínez', rol: 'cliente');

// Sesión en memoria: empieza iniciada y cuenta cuántas veces se cerró.
class _AuthFalso extends AuthService {
  _AuthFalso() : super(api: ApiClient(), storage: MemorySessionStorage());
  int cierres = 0;

  @override
  Future<Usuario?> sesionGuardada() async => cierres == 0 ? _ana : null;

  @override
  Future<void> cerrarSesion() async => cierres++;
}

class _PerfilFalso extends PerfilService {
  _PerfilFalso()
    : super(
        api: ApiClient(),
        pedidos: PedidoService(api: ApiClient()),
        favoritos: FavoritoService(api: ApiClient()),
      );

  @override
  Future<Perfil> perfil() async => Perfil.fromJson({'nombre': 'Ana Martínez', 'email': 'ana.martinez@correo.com'});

  @override
  Future<ResumenCliente> resumen() async => const ResumenCliente(pedidos: 3, apartados: 2, favoritos: 1);
}

class _CarritoFalso extends CarritoService {
  _CarritoFalso() : super(api: ApiClient());

  @override
  Future<Carrito> obtener() async =>
      const Carrito(items: [ItemCarrito(id: 1, productoId: 58, nombre: 'Anillo corazón', cantidad: 1, precioVenta: 1250, stock: 3)]);
}

class _FavoritosFalso extends FavoritoService {
  _FavoritosFalso() : super(api: ApiClient());

  @override
  Future<List<Producto>> lista() async => const [Producto(id: 58, nombre: 'Anillo corazón', precioVenta: 1250, stock: 3)];
}

Future<(AuthProvider, CarritoProvider, FavoritosProvider, _AuthFalso)> _abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final servicio = _AuthFalso();
  final auth = AuthProvider(servicio);
  await auth.restaurarSesion();
  final carrito = CarritoProvider(_CarritoFalso());
  final favoritos = FavoritosProvider(_FavoritosFalso());
  await carrito.cargar();
  await favoritos.cargar();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PerfilService>.value(value: _PerfilFalso()),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: carrito),
        ChangeNotifierProvider.value(value: favoritos),
      ],
      child: MaterialApp(
        theme: AppTheme.oscuro(),
        initialRoute: '/perfil',
        routes: {
          '/': (_) => const Scaffold(body: Text('Pantalla de inicio')),
          '/perfil': (_) => const PerfilScreen(),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (auth, carrito, favoritos, servicio);
}

Future<void> _tocarCerrarSesion(WidgetTester tester) async {
  final boton = find.text('Cerrar sesión');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Pide confirmación antes de cerrar la sesión', (tester) async {
    final (auth, _, _, servicio) = await _abrir(tester);
    await _tocarCerrarSesion(tester);

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(find.text('Tu carrito y tus favoritos se quedan guardados en tu cuenta para la próxima vez.'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(servicio.cierres, 0);
    expect(auth.autenticado, isTrue);
    expect(find.byType(PerfilScreen), findsOneWidget);
  });

  testWidgets('Al confirmar borra la sesión, olvida carrito y favoritos y regresa al inicio sin poder volver', (tester) async {
    final (auth, carrito, favoritos, servicio) = await _abrir(tester);
    expect(carrito.piezas, 1);
    expect(favoritos.esFavorita(58), isTrue);

    await _tocarCerrarSesion(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(servicio.cierres, 1);
    expect(auth.autenticado, isFalse);
    expect(carrito.piezas, 0);
    expect(favoritos.esFavorita(58), isFalse);
    expect(favoritos.lista, isEmpty);
    expect(find.text('Pantalla de inicio'), findsOneWidget);
    // El perfil ya no queda debajo: no se puede regresar a pantallas de la cuenta.
    expect(Navigator.of(tester.element(find.text('Pantalla de inicio'))).canPop(), isFalse);
  });
}
