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
  _ServicioFalso(this.paginas, {this.falla = false, this.listaCategorias = const []}) : super(api: ApiClient());
  final List<List<Producto>> paginas;
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
  Future<List<Categoria>> categorias() async => listaCategorias;
}

Producto _pieza(int id, {double precio = 890, double? promocion, int stock = 5, bool personalizable = false}) => Producto(
    id: id, nombre: 'Anillo $id', precioVenta: precio, precioPromocion: promocion, stock: stock, personalizable: personalizable);

Future<void> _abrir(WidgetTester tester, ProductoService servicio) async {
  await tester.pumpWidget(
    Provider<ProductoService>.value(
      value: servicio,
      child: MaterialApp(theme: AppTheme.oscuro(), home: const CatalogoScreen()),
    ),
  );
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
    await _abrir(tester, _ServicioFalso([
      [_pieza(1, precio: 890), _pieza(2, precio: 1100, personalizable: true)],
    ]));

    expect(find.text('CATÁLOGO'), findsOneWidget);
    expect(find.text('Anillo 1'), findsOneWidget);
    expect(find.text('\$890'), findsOneWidget);
    expect(find.text('\$1,100'), findsOneWidget);
    expect(find.text('Personalizable'), findsOneWidget);
    expect(find.text('2 piezas'), findsOneWidget);
  });

  testWidgets('La barra inferior marca el catálogo como sección activa', (tester) async {
    final semantica = tester.ensureSemantics();
    await _abrir(tester, _ServicioFalso([
      [_pieza(1)],
    ]));

    expect(find.bySemanticsLabel('Catálogo'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Catálogo')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.bySemanticsLabel('Carrito')), isSemantics(isSelected: false, isButton: true));

    await tester.tap(find.bySemanticsLabel('Carrito'));
    await tester.pump();
    expect(find.text('Disponible muy pronto'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('Marca las piezas agotadas y tacha el precio con descuento', (tester) async {
    await _abrir(tester, _ServicioFalso([
      [_pieza(1, precio: 1000, promocion: 800), _pieza(2, stock: 0)],
    ]));

    expect(find.text('\$800'), findsOneWidget);
    final tachado = tester.widget<Text>(find.text('\$1,000'));
    expect(tachado.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('Agotado'), findsOneWidget);
  });

  testWidgets('Pide la siguiente página al bajar hasta el final', (tester) async {
    final servicio = _ServicioFalso([
      List.generate(ProductoService.porPagina, (i) => _pieza(i)),
      [_pieza(100)],
    ]);
    await _abrir(tester, servicio);

    await tester.dragUntilVisible(find.text('Anillo 100'), find.byType(CustomScrollView), const Offset(0, -500));
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
      listaCategorias: const [Categoria(id: 1, nombre: 'Anillos'), Categoria(id: 14, nombre: 'esclavas')],
    );
    await _abrir(tester, servicio);

    expect(find.text('Nuestras joyas'), findsOneWidget);
    expect(find.text('Esclavas'), findsOneWidget);

    await tester.tap(find.text('Anillos'));
    await tester.pumpAndSettle();
    expect(servicio.categoriasPedidas.last, 1);
    expect(find.text('Anillos'), findsNWidgets(2));

    // Tocar otra vez la categoría activa vuelve a mostrar todo el catálogo.
    await tester.tap(find.text('Anillos').last);
    await tester.pumpAndSettle();
    expect(servicio.categoriasPedidas.last, isNull);
    expect(find.text('Nuestras joyas'), findsOneWidget);
  });
}
