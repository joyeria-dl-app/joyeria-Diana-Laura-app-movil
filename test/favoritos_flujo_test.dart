import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/carrito.dart';
import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/providers/favoritos_provider.dart';
import 'package:joyeria_diana_laura/routes/app_routes.dart';
import 'package:joyeria_diana_laura/screens/catalogo_screen.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/screens/favoritos_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';
import 'package:joyeria_diana_laura/widgets/barra_navegacion.dart';
import 'package:joyeria_diana_laura/widgets/tarjeta_producto.dart';

// HU-10 · Criterio de aceptación: una pieza marcada como favorita aparece en
// la lista de favoritos del cliente, también en el sitio web. El backend se
// simula en memoria y lo comparten la app y el sitio web.

const _anillo = Producto(id: 58, nombre: 'Anillo corazón', precioVenta: 1250, stock: 4, categoriaNombre: 'Anillos');
const _aretes = Producto(id: 61, nombre: 'Aretes gota', precioVenta: 540, stock: 2, categoriaNombre: 'Aretes');

class _Catalogo extends ProductoService {
  _Catalogo() : super(api: ApiClient());

  @override
  Future<List<Producto>> productos({int? categoriaId, String? busqueda, int pagina = 0}) async => pagina == 0 ? [_anillo, _aretes] : [];

  @override
  Future<List<Categoria>> categorias() async => [];

  @override
  Future<DetalleProducto> detalle(int id) async => DetalleProducto(producto: id == _anillo.id ? _anillo : _aretes);

  @override
  Future<({double promedio, int total})> resenas(int id) async => (promedio: 0.0, total: 0);
}

// Favoritos guardados en el "backend" por cuenta.
class _Backend extends FavoritoService {
  _Backend([List<Producto> iniciales = const []]) : guardadas = List.of(iniciales), super(api: ApiClient());
  final List<Producto> guardadas;

  @override
  Future<List<Producto>> lista() async => List.of(guardadas.reversed);

  @override
  Future<bool> esFavorito(int productoId) async => guardadas.any((p) => p.id == productoId);

  @override
  Future<bool> alternar(int productoId) async {
    if (guardadas.any((p) => p.id == productoId)) {
      guardadas.removeWhere((p) => p.id == productoId);
      return false;
    }
    guardadas.add(productoId == _anillo.id ? _anillo : _aretes);
    return true;
  }

  // Lo que mostraría Mis Favoritos en el sitio web con la misma cuenta.
  List<String> get enSitioWeb => guardadas.map((p) => p.nombre).toList();
}

class _SinCarrito extends CarritoService {
  _SinCarrito() : super(api: ApiClient());

  @override
  Future<Carrito> obtener() async => const Carrito();
}

Future<void> _abrir(WidgetTester tester, _Backend backend, Widget inicio) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ProductoService>.value(value: _Catalogo()),
        ChangeNotifierProvider(create: (_) => FavoritosProvider(backend)),
        ChangeNotifierProvider(create: (_) => CarritoProvider(_SinCarrito())),
      ],
      child: MaterialApp(theme: AppTheme.oscuro(), home: inicio, routes: {AppRoutes.favoritos: (_) => const FavoritosScreen()}),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tarjeta(String nombre) => find.ancestor(of: find.text(nombre), matching: find.byType(TarjetaProducto));

// Corazón de la tarjeta: relleno si es favorita, con contorno si no.
Finder _corazonDe(String nombre) => find.descendant(
  of: _tarjeta(nombre),
  matching: find.byWidgetPredicate((w) => w is Icon && (w.icon == Icons.favorite_rounded || w.icon == Icons.favorite_border_rounded)),
);

bool _marcada(WidgetTester tester, String nombre) => tester.widget<Icon>(_corazonDe(nombre)).icon == Icons.favorite_rounded;

void main() {
  testWidgets('Marcar el corazón en el catálogo la guarda y aparece en Favoritos', (tester) async {
    final backend = _Backend();
    await _abrir(tester, backend, const CatalogoScreen());

    await tester.tap(_corazonDe('Aretes gota'));
    await tester.pumpAndSettle();
    expect(backend.enSitioWeb, ['Aretes gota']);

    await tester.tap(find.text('Ver favoritos'));
    await tester.pumpAndSettle();
    expect(find.byType(FavoritosScreen), findsOneWidget);
    expect(find.text('Aretes gota'), findsOneWidget);
    expect(find.text('1 pieza guardada'), findsOneWidget);
  });

  testWidgets('Marcar el corazón del detalle la guarda en el sitio web', (tester) async {
    final backend = _Backend();
    await _abrir(tester, backend, const DetalleScreen(productoId: 58));

    await tester.tap(find.bySemanticsLabel('Guardar en favoritos'));
    await tester.pumpAndSettle();

    expect(backend.enSitioWeb, ['Anillo corazón']);
    expect(find.bySemanticsLabel('Quitar de favoritos'), findsOneWidget);
  });

  testWidgets('Lo guardado en el sitio web aparece en Favoritos y marcado en el catálogo', (tester) async {
    final backend = _Backend([_anillo]);
    await _abrir(tester, backend, const CatalogoScreen());

    expect(_marcada(tester, 'Anillo corazón'), isTrue);
    expect(_marcada(tester, 'Aretes gota'), isFalse);
  });

  testWidgets('Quitarla desde Favoritos también la quita del sitio web', (tester) async {
    final backend = _Backend([_anillo, _aretes]);
    await _abrir(tester, backend, const FavoritosScreen());
    expect(find.text('2 piezas guardadas'), findsOneWidget);

    await tester.tap(_corazonDe('Anillo corazón'));
    await tester.pumpAndSettle();

    expect(backend.enSitioWeb, ['Aretes gota']);
    expect(find.text('Anillo corazón'), findsNothing);
    expect(find.text('1 pieza guardada'), findsOneWidget);
  });

  testWidgets('Deshacer vuelve a guardar la pieza que se quitó', (tester) async {
    final backend = _Backend([_anillo]);
    await _abrir(tester, backend, const FavoritosScreen());

    await tester.tap(_corazonDe('Anillo corazón'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(backend.enSitioWeb, ['Anillo corazón']);
    expect(find.text('Anillo corazón'), findsOneWidget);
  });

  testWidgets('El botón Favoritos de la barra inferior abre la lista', (tester) async {
    await _abrir(
      tester,
      _Backend(),
      const Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: BarraNavegacion(actual: Seccion.catalogo),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Favoritos'));
    await tester.pumpAndSettle();

    expect(find.byType(FavoritosScreen), findsOneWidget);
  });
}
