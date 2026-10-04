import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/carrito.dart';
import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/providers/carrito_provider.dart';
import 'package:joyeria_diana_laura/providers/favoritos_provider.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/carrito_service.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// Carrito sin backend: guarda lo agregado o falla como se le indique.
class _CarritoFalso extends CarritoService {
  _CarritoFalso({this.error}) : super(api: ApiClient());
  CarritoException? error;
  final List<(int, String?)> agregadas = [];

  @override
  Future<void> agregar(int productoId, {int cantidad = 1, String? talla}) async {
    if (error != null) throw error!;
    agregadas.add((productoId, talla));
  }

  @override
  Future<Carrito> obtener() async => const Carrito();
}

// Devuelve el detalle de prueba o el error indicado, sin llamar al backend.
class _ServicioFalso extends ProductoService {
  _ServicioFalso({this.detalleFalso, this.error, this.resenasFalsas = (promedio: 0, total: 0)}) : super(api: ApiClient());
  DetalleProducto? detalleFalso;
  ProductoException? error;
  ({double promedio, int total}) resenasFalsas;
  int pedidas = 0;

  @override
  Future<DetalleProducto> detalle(int id) async {
    pedidas++;
    if (error != null) throw error!;
    return detalleFalso!;
  }

  @override
  Future<({double promedio, int total})> resenas(int id) async => resenasFalsas;
}

// Favoritos sin backend: guarda los ids marcados o falla como se le indique.
class _FavoritosFalso extends FavoritoService {
  _FavoritosFalso({this.error}) : super(api: ApiClient());
  FavoritoException? error;
  final Set<int> ids = {};

  @override
  Future<bool> esFavorito(int productoId) async => ids.contains(productoId);

  @override
  Future<bool> alternar(int productoId) async {
    if (error != null) throw error!;
    return ids.remove(productoId) ? false : ids.add(productoId);
  }
}

DetalleProducto _anillo({
  int stock = 3,
  bool personalizable = true,
  String? medidas = 'Talla 7',
  double? promocion,
  List<String> imagenes = const [],
}) =>
    DetalleProducto(
      producto: Producto(
        id: 58,
        nombre: 'Anillo corazón',
        precioVenta: 1250,
        precioPromocion: promocion,
        stock: stock,
        personalizable: personalizable,
        categoriaNombre: 'Anillos',
        material: 'Plata .925',
      ),
      descripcion: 'Plata .925 con circonia rosa en corte corazón.',
      pesoGramos: 4.673,
      medidas: medidas,
      imagenes: imagenes,
    );

const _fotos = ['https://img/1.jpg', 'https://img/2.jpg', 'https://img/3.jpg', 'https://img/4.jpg'];

Future<void> _abrir(WidgetTester tester, ProductoService servicio, {CarritoService? carrito, FavoritoService? favoritos}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ProductoService>.value(value: servicio),
        ChangeNotifierProvider(create: (_) => CarritoProvider(carrito ?? _CarritoFalso())),
        ChangeNotifierProvider(create: (_) => FavoritosProvider(favoritos ?? _FavoritosFalso())),
      ],
      child: MaterialApp(theme: AppTheme.oscuro(), home: const DetalleScreen(productoId: 58)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Muestra la pieza con sus datos, etiquetas, talla y precio', (tester) async {
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo()));

    expect(find.text('Anillo corazón'), findsOneWidget);
    expect(find.text('Anillos · Plata .925 · 4.7 g'), findsOneWidget);
    expect(find.text('Plata .925 con circonia rosa en corte corazón.'), findsOneWidget);
    expect(find.text('Personalizable'), findsOneWidget);
    expect(find.text('Quedan 3'), findsOneWidget);
    expect(find.text('Talla 7'), findsOneWidget);
    expect(find.textContaining('\$1,250', findRichText: true), findsOneWidget);
    expect(find.text('Agregar'), findsOneWidget);
  });

  testWidgets('Agregar guarda la pieza con su talla en el carrito', (tester) async {
    final carrito = _CarritoFalso();
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo()), carrito: carrito);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(carrito.agregadas, [(58, 'Talla 7')]);
    expect(find.text('Agregada a tu carrito'), findsOneWidget);
    expect(find.text('Ver carrito'), findsOneWidget);
  });

  testWidgets('Sin sesión Agregar invita a iniciar sesión', (tester) async {
    final carrito = _CarritoFalso(error: const CarritoException('Inicia sesión para usar tu carrito.', sinSesion: true));
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo()), carrito: carrito);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Inicia sesión para agregar piezas a tu carrito'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('Muestra las estrellas en 0 mientras la pieza no tenga reseñas', (tester) async {
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo()));

    expect(find.text('0'), findsOneWidget);
    expect(find.text(' · 0 reseñas'), findsOneWidget);
  });

  testWidgets('Con reseñas muestra el promedio y el total del sitio web', (tester) async {
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo(), resenasFalsas: (promedio: 4.9, total: 38)));

    expect(find.text('4.9'), findsOneWidget);
    expect(find.text(' · 38 reseñas'), findsOneWidget);
  });

  testWidgets('El corazón guarda la pieza en favoritos y se marca (7g)', (tester) async {
    final favoritos = _FavoritosFalso();
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo()), favoritos: favoritos);

    await tester.tap(find.bySemanticsLabel('Guardar en favoritos'));
    await tester.pumpAndSettle();

    expect(favoritos.ids, {58});
    expect(find.bySemanticsLabel('Quitar de favoritos'), findsOneWidget);
    expect(find.text('Guardada en tus favoritos'), findsOneWidget);
    expect(find.text('Ver favoritos'), findsOneWidget);
  });

  testWidgets('Si ya era favorita aparece marcada y al tocarla se quita con Deshacer (7f)', (tester) async {
    final favoritos = _FavoritosFalso()..ids.add(58);
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo()), favoritos: favoritos);
    expect(find.bySemanticsLabel('Quitar de favoritos'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Quitar de favoritos'));
    await tester.pumpAndSettle();
    expect(favoritos.ids, isEmpty);
    expect(find.text('Quitada de tus favoritos'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(favoritos.ids, {58});
  });

  testWidgets('Sin sesión el corazón invita a iniciar sesión y no se marca', (tester) async {
    final favoritos = _FavoritosFalso(error: const FavoritoException('Inicia sesión', sinSesion: true));
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo()), favoritos: favoritos);

    await tester.tap(find.bySemanticsLabel('Guardar en favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('Inicia sesión para guardar tus favoritos'), findsOneWidget);
    expect(find.bySemanticsLabel('Guardar en favoritos'), findsOneWidget);
  });

  testWidgets('Sin talla registrada no muestra la sección de talla', (tester) async {
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo(medidas: null, stock: 20)));

    expect(find.text('Talla'), findsNothing);
    expect(find.textContaining('Quedan'), findsNothing);
  });

  testWidgets('Con promoción muestra el precio final y tacha el de venta', (tester) async {
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo(promocion: 1000)));

    expect(find.textContaining('\$1,000', findRichText: true), findsOneWidget);
    final tachado = tester.widget<Text>(find.text('\$1,250'));
    expect(tachado.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('Una pieza agotada muestra el aviso y el botón desactivado', (tester) async {
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo(stock: 0)));

    expect(find.text('Agotado'), findsNWidgets(2));
    expect(find.text('Agregar'), findsNothing);
    expect(find.text('Personalizable'), findsNothing);
  });

  testWidgets('Si la pieza ya no existe ofrece volver al catálogo', (tester) async {
    await _abrir(
      tester,
      _ServicioFalso(error: const ProductoException('Esta pieza ya no está disponible.', noEncontrado: true)),
    );

    expect(find.text('Pieza no disponible'), findsOneWidget);
    expect(find.text('Ver catálogo'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('Sin conexión permite reintentar y luego muestra la pieza', (tester) async {
    final servicio = _ServicioFalso(detalleFalso: _anillo(), error: const ProductoException('Sin red'));
    await _abrir(tester, servicio);
    expect(find.text('Sin conexión'), findsOneWidget);

    servicio.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(servicio.pedidas, 2);
    expect(find.text('Anillo corazón'), findsOneWidget);
  });

  // Criterio de aceptación de la HU-08: se pueden deslizar todas las imágenes de la pieza.
  testWidgets('Con varias fotos se deslizan todas hasta la última', (tester) async {
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo(imagenes: _fotos)));

    final galeria = find.byType(PageView);
    expect(galeria, findsOneWidget);
    for (var i = 1; i < _fotos.length; i++) {
      await tester.drag(galeria, const Offset(-500, 0));
      await tester.pumpAndSettle();
    }
    expect(tester.widget<PageView>(galeria).controller!.page, _fotos.length - 1);
  });

  testWidgets('Con una sola foto no muestra la galería deslizable', (tester) async {
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo(imagenes: [_fotos.first])));

    expect(find.byType(PageView), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Foto 1 de')), findsNothing);
  });

  testWidgets('El botón Regresar vuelve a la pantalla anterior', (tester) async {
    await tester.pumpWidget(
      Provider<ProductoService>.value(
        value: _ServicioFalso(detalleFalso: _anillo()),
        child: MaterialApp(
          theme: AppTheme.oscuro(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const DetalleScreen(productoId: 58))),
              child: const Text('Catálogo'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Catálogo'));
    await tester.pumpAndSettle();
    expect(find.text('Anillo corazón'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Regresar'));
    await tester.pumpAndSettle();
    expect(find.text('Anillo corazón'), findsNothing);
    expect(find.text('Catálogo'), findsOneWidget);
  });
}
