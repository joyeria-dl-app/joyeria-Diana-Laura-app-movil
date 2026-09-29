import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/screens/detalle_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';

// Devuelve el detalle de prueba o el error indicado, sin llamar al backend.
class _ServicioFalso extends ProductoService {
  _ServicioFalso({this.detalleFalso, this.error}) : super(api: ApiClient());
  DetalleProducto? detalleFalso;
  ProductoException? error;
  int pedidas = 0;

  @override
  Future<DetalleProducto> detalle(int id) async {
    pedidas++;
    if (error != null) throw error!;
    return detalleFalso!;
  }
}

DetalleProducto _anillo({int stock = 3, bool personalizable = true, String? medidas = 'Talla 7', double? promocion}) => DetalleProducto(
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
    );

Future<void> _abrir(WidgetTester tester, ProductoService servicio) async {
  await tester.pumpWidget(
    Provider<ProductoService>.value(
      value: servicio,
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

  testWidgets('Agregar y favoritos avisan que estarán disponibles pronto', (tester) async {
    await _abrir(tester, _ServicioFalso(detalleFalso: _anillo()));

    await tester.tap(find.text('Agregar'));
    await tester.pump();
    expect(find.text('Disponible muy pronto'), findsOneWidget);
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
}
