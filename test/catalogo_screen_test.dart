// TIPO: widget
// ALCANCE: HU-07 · pantalla del catálogo: tarjetas, filtros y estados vacíos
// EJECUCIÓN: pipelines Pruebas unitarias y Flutter CI en cada PR; los archivos de test/ corren EN PARALELO entre sí y los casos de este archivo EN SECUENCIA. flutter test test/catalogo_screen_test.dart
// DATOS: backend simulado en memoria (sin red); productos de ejemplo

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/screens/catalogo_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';
import 'package:joyeria_diana_laura/utils/formato.dart';

// Devuelve productos de prueba sin llamar al backend.
class _ServicioFalso extends ProductoService {
  _ServicioFalso(this.paginas, {this.falla = false, this.listaCategorias = const [], this.total}) : super(api: ApiClient());
  final List<List<Producto>> paginas;
  // Lo que respondería el backend en total_filtrado; null como un backend sin ese dato.
  final int? total;
  final List<Categoria> listaCategorias;
  bool falla;
  final List<int> pedidas = [];
  final List<int?> categoriasPedidas = [];

  @override
  Future<List<Producto>> productos({int? categoriaId, String? busqueda, int pagina = 0}) async {
    pedidas.add(pagina);
    categoriasPedidas.add(categoriaId);
    if (falla) throw const ProductoException('No se pudo cargar el catálogo.');
    return pagina < paginas.length ? paginas[pagina] : [];
  }

  @override
  Future<PaginaProductos> pagina({int? categoriaId, String? busqueda, int pagina = 0}) async =>
      PaginaProductos(await productos(categoriaId: categoriaId, busqueda: busqueda, pagina: pagina), total);

  @override
  Future<List<Categoria>> categorias() async {
    if (falla) throw const ProductoException('No se pudo cargar el catálogo.');
    return listaCategorias;
  }
}

Producto _pieza(int id, {double precio = 890, double? promocion, int stock = 5, bool personalizable = false}) =>
    Producto(id: id, nombre: 'Anillo $id', precioVenta: precio, precioPromocion: promocion, stock: stock, personalizable: personalizable);

Future<void> _abrir(WidgetTester tester, ProductoService servicio) async {
  await tester.pumpWidget(
    Provider<ProductoService>.value(
      value: servicio,
      child: MaterialApp(
        theme: AppTheme.oscuro(),
        home: const CatalogoScreen(),
        routes: {'/perfil': (_) => const Scaffold(body: Text('Pantalla de perfil'))},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Los botones de página van al final de la cuadrícula: se baja hasta que se construyan.
Future<void> _alPaginador(WidgetTester tester, String clave) async {
  await tester.scrollUntilVisible(find.byKey(Key(clave)), 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  test('Formatea los precios como en los bocetos', () {
    expect(formatoPrecio(890), '\$890');
    expect(formatoPrecio(1250), '\$1,250');
    expect(formatoPrecio(565.47), '\$565.47');
    expect(formatoPrecio(1234567.5), '\$1,234,567.50');
  });

  testWidgets('Muestra las piezas con su nombre y precio', (tester) async {
    await _abrir(
      tester,
      _ServicioFalso([
        [_pieza(1, precio: 890), _pieza(2, precio: 1100, personalizable: true)],
      ]),
    );

    expect(find.text('CATÁLOGO'), findsOneWidget);
    expect(find.text('Anillo 1'), findsOneWidget);
    expect(find.text('\$890'), findsOneWidget);
    expect(find.text('\$1,100'), findsOneWidget);
    expect(find.text('Personalizable'), findsOneWidget);
    expect(find.text('2 piezas'), findsOneWidget);
  });

  testWidgets('La barra inferior marca el catálogo como sección activa', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(
      tester,
      _ServicioFalso([
        [_pieza(1)],
      ]),
    );

    expect(find.bySemanticsLabel('Catálogo'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Catálogo')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.bySemanticsLabel('Carrito')), isSemantics(isSelected: false, isButton: true));

    // Perfil abre Mi perfil (HU-14).
    await tester.tap(find.bySemanticsLabel('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla de perfil'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('Marca las piezas agotadas y tacha el precio con descuento', (tester) async {
    await _abrir(
      tester,
      _ServicioFalso([
        [_pieza(1, precio: 1000, promocion: 800), _pieza(2, stock: 0)],
      ]),
    );

    expect(find.text('\$800'), findsOneWidget);
    final tachado = tester.widget<Text>(find.text('\$1,000'));
    expect(tachado.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('Agotado'), findsOneWidget);
  });

  // #279: páginas numeradas; cada página se pide al elegirla y reemplaza a la anterior.
  testWidgets('Muestra 5 piezas por página y la siguiente se pide al tocar su número', (tester) async {
    final servicio = _ServicioFalso([
      List.generate(ProductoService.porPagina, (i) => _pieza(i)),
      [_pieza(100)],
    ], total: ProductoService.porPagina + 1);
    await _abrir(tester, servicio);

    expect(servicio.pedidas, [0]);
    expect(find.text('6 piezas · página 1 de 2'), findsOneWidget);

    await _alPaginador(tester, 'pagina_2');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pagina_2')));
    await tester.pumpAndSettle();

    expect(servicio.pedidas, [0, 1]);
    expect(find.text('Anillo 100'), findsOneWidget);
    expect(find.text('Anillo 0'), findsNothing);
    expect(find.text('6 piezas · página 2 de 2'), findsOneWidget);
  });

  testWidgets('Anterior y Siguiente cambian de página y se desactivan en los extremos', (tester) async {
    final servicio = _ServicioFalso([
      List.generate(ProductoService.porPagina, (i) => _pieza(i)),
      [_pieza(100)],
    ], total: ProductoService.porPagina + 1);
    await _abrir(tester, servicio);

    IconButton boton(String clave) => tester.widget<IconButton>(find.byKey(Key(clave)));
    await _alPaginador(tester, 'pagina_anterior');
    expect(boton('pagina_anterior').onPressed, isNull);

    await _alPaginador(tester, 'pagina_siguiente');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pagina_siguiente')));
    await tester.pumpAndSettle();
    expect(find.text('Anillo 100'), findsOneWidget);
    await _alPaginador(tester, 'pagina_siguiente');
    expect(boton('pagina_siguiente').onPressed, isNull);

    await _alPaginador(tester, 'pagina_anterior');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pagina_anterior')));
    await tester.pumpAndSettle();
    expect(servicio.pedidas, [0, 1, 0]);
    expect(find.text('Anillo 0'), findsOneWidget);
  });

  testWidgets('Sin el total del backend se pasa de página con Siguiente', (tester) async {
    final servicio = _ServicioFalso([
      List.generate(ProductoService.porPagina, (i) => _pieza(i)),
      [_pieza(100)],
    ]);
    await _abrir(tester, servicio);

    expect(find.text('Página 1'), findsWidgets);
    await _alPaginador(tester, 'pagina_siguiente');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pagina_siguiente')));
    await tester.pumpAndSettle();

    expect(servicio.pedidas, [0, 1]);
    expect(find.text('Anillo 100'), findsOneWidget);
  });

  testWidgets('Si no hay conexión muestra el error y permite reintentar', (tester) async {
    final servicio = _ServicioFalso([
      [_pieza(1)],
    ], falla: true);
    await _abrir(tester, servicio);

    expect(find.text('Sin conexión'), findsOneWidget);

    servicio.falla = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Anillo 1'), findsOneWidget);
  });

  testWidgets('Sin piezas muestra un aviso', (tester) async {
    await _abrir(tester, _ServicioFalso([[]]));
    expect(find.text('Aún no hay piezas'), findsOneWidget);
  });

  testWidgets('Al elegir una categoría filtra las piezas y la usa como título', (tester) async {
    final servicio = _ServicioFalso(
      [
        [_pieza(1)],
      ],
      listaCategorias: const [
        Categoria(id: 1, nombre: 'Anillos'),
        Categoria(id: 14, nombre: 'esclavas'),
      ],
    );
    await _abrir(tester, servicio);

    expect(find.text('Nuestras joyas'), findsOneWidget);
    // Sin filtro cada categoría aparece en su círculo y como título de su sección (#254).
    expect(find.text('Esclavas'), findsNWidgets(2));

    await tester.tap(find.text('Anillos').first);
    await tester.pumpAndSettle();
    expect(servicio.categoriasPedidas.last, 1);
    expect(find.text('Anillos'), findsNWidgets(2));

    // Tocar otra vez la categoría activa vuelve a mostrar todo el catálogo.
    await tester.tap(find.text('Anillos').last);
    await tester.pumpAndSettle();
    // Sin filtro vuelven las secciones (#254).
    expect(find.text('Nuestras joyas'), findsOneWidget);
    expect(find.text('2 categorías'), findsOneWidget);
  });

  testWidgets('Al reintentar sin conexión también vuelven las categorías', (tester) async {
    final servicio = _ServicioFalso(
      [
        [_pieza(1)],
      ],
      falla: true,
      listaCategorias: const [Categoria(id: 1, nombre: 'Anillos')],
    );
    await _abrir(tester, servicio);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Anillos'), findsNothing);

    servicio.falla = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Anillo 1'), findsOneWidget);
    expect(find.text('Anillos'), findsNWidgets(2));
  });

  testWidgets('Con un filtro activo las páginas siguientes siguen siendo de esa categoría', (tester) async {
    final servicio = _ServicioFalso(
      [
        List.generate(ProductoService.porPagina, (i) => _pieza(i)),
        [_pieza(100)],
      ],
      listaCategorias: const [Categoria(id: 3, nombre: 'Pulseras')],
    );
    await _abrir(tester, servicio);
    await tester.tap(find.text('Pulseras').first);
    await tester.pumpAndSettle();

    await _alPaginador(tester, 'pagina_siguiente');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pagina_siguiente')));
    await tester.pumpAndSettle();

    // Última petición: página 1 de la categoría 3.
    expect(servicio.pedidas.last, 1);
    expect(servicio.categoriasPedidas.last, 3);
  });

  testWidgets('Una categoría sin piezas muestra el aviso y conserva la fila de categorías', (tester) async {
    final servicio = _ServicioFalso(
      [
        [_pieza(1)],
      ],
      listaCategorias: const [Categoria(id: 24, nombre: 'Cadenas')],
    );
    await _abrir(tester, servicio);
    servicio.paginas.clear();
    await tester.tap(find.text('Cadenas').first);
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay piezas'), findsOneWidget);
    expect(find.text('Cadenas'), findsNWidgets(2));
  });

  testWidgets('Si fallan las categorías el catálogo se sigue mostrando', (tester) async {
    await _abrir(
      tester,
      _ServicioCategoriasFallan([
        [_pieza(1)],
      ]),
    );

    expect(find.text('Anillo 1'), findsOneWidget);
    expect(find.text('Nuestras joyas'), findsOneWidget);
  });

  testWidgets('Cuando ya no hay más páginas muestra el total exacto', (tester) async {
    await _abrir(
      tester,
      _ServicioFalso([
        [_pieza(1), _pieza(2), _pieza(3)],
      ]),
    );
    expect(find.text('3 piezas'), findsOneWidget);
  });

  testWidgets('Una pieza agotada no muestra la etiqueta Personalizable', (tester) async {
    await _abrir(
      tester,
      _ServicioFalso([
        [_pieza(1, stock: 0, personalizable: true)],
      ]),
    );
    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text('Personalizable'), findsNothing);
  });

  testWidgets('Al tocar una pieza abre su detalle', (tester) async {
    await _abrir(
      tester,
      _ServicioDetalle([
        [_pieza(7)],
      ]),
    );

    await tester.tap(find.text('Anillo 7'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle 7'), findsOneWidget);
  });

  testWidgets('Sin filtro organiza las piezas por secciones de categoría y omite las vacías', (tester) async {
    final servicio = _PorCategoria({
      1: [Producto(id: 1, nombre: 'Anillo de promesa', precioVenta: 449.5, stock: 3)],
      2: [Producto(id: 2, nombre: 'Collar de perlas', precioVenta: 890, stock: 2)],
      3: [],
    });
    await _abrir(tester, servicio);

    expect(find.text('3 categorías'), findsOneWidget);
    expect(find.text('Anillo de promesa'), findsOneWidget);
    expect(find.text('Collar de perlas'), findsOneWidget);
    expect(find.text('Ver todo'), findsNWidgets(2));
    // Cada sección pidió solo sus piezas; la cuadrícula general no se pidió.
    expect(servicio.categoriasPedidas.toSet(), {1, 2, 3});
  });

  testWidgets('Ver todo de una sección abre esa categoría en cuadrícula', (tester) async {
    final servicio = _PorCategoria({
      1: [Producto(id: 1, nombre: 'Anillo de promesa', precioVenta: 449.5, stock: 3)],
      2: [Producto(id: 2, nombre: 'Collar de perlas', precioVenta: 890, stock: 2)],
    });
    await _abrir(tester, servicio);
    await tester.tap(find.text('Ver todo').first);
    await tester.pumpAndSettle();

    expect(find.text('Ver todo'), findsNothing);
    expect(find.text('1 piezas'), findsOneWidget);
    expect(find.text('Anillo de promesa'), findsOneWidget);
    expect(find.text('Collar de perlas'), findsNothing);
  });
}

class _ServicioCategoriasFallan extends _ServicioFalso {
  _ServicioCategoriasFallan(super.paginas);

  @override
  Future<List<Categoria>> categorias() async => throw const ProductoException('No se pudo cargar el catálogo.');
}

class _ServicioDetalle extends _ServicioFalso {
  _ServicioDetalle(super.paginas);

  @override
  Future<DetalleProducto> detalle(int id) async => DetalleProducto(
    producto: Producto(id: id, nombre: 'Detalle $id', precioVenta: 890, stock: 5),
  );
}

// Responde según la categoría pedida, como el backend.
class _PorCategoria extends ProductoService {
  _PorCategoria(this.porCategoria) : super(api: ApiClient());
  final Map<int, List<Producto>> porCategoria;
  final List<int?> categoriasPedidas = [];

  @override
  Future<List<Producto>> productos({int? categoriaId, String? busqueda, int pagina = 0}) async {
    categoriasPedidas.add(categoriaId);
    if (pagina > 0) return [];
    return categoriaId == null ? porCategoria.values.expand((p) => p).toList() : porCategoria[categoriaId] ?? [];
  }

  @override
  Future<PaginaProductos> pagina({int? categoriaId, String? busqueda, int pagina = 0}) async =>
      PaginaProductos(await productos(categoriaId: categoriaId, busqueda: busqueda, pagina: pagina), null);

  @override
  Future<List<Categoria>> categorias() async => [
    for (final id in porCategoria.keys) Categoria(id: id, nombre: const {1: 'Anillos', 2: 'Collares', 3: 'Relojes'}[id]!),
  ];
}
