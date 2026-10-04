import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/providers/favoritos_provider.dart';
import 'package:joyeria_diana_laura/screens/favoritos_screen.dart';
import 'package:joyeria_diana_laura/services/api_client.dart';
import 'package:joyeria_diana_laura/services/favorito_service.dart';
import 'package:joyeria_diana_laura/theme/app_theme.dart';
import 'package:joyeria_diana_laura/widgets/tarjeta_producto.dart';

// Favoritos en memoria que se comportan como el backend, sin llamarlo.
class _ServicioFalso extends FavoritoService {
  _ServicioFalso(this.piezas, {this.error}) : super(api: ApiClient());
  List<Producto> piezas;
  FavoritoException? error;
  final List<int> alternadas = [];

  @override
  Future<List<Producto>> lista() async {
    if (error != null) throw error!;
    return List.of(piezas);
  }

  @override
  Future<bool> alternar(int productoId) async {
    alternadas.add(productoId);
    piezas = piezas.where((p) => p.id != productoId).toList();
    return false;
  }
}

const _anillo = Producto(id: 1, nombre: 'Anillo flor rosa', precioVenta: 890, stock: 3, promedioResenas: 4.9, totalResenas: 38);
const _aretes = Producto(id: 2, nombre: 'Aretes gota', precioVenta: 540, stock: 5, personalizable: true);
const _trebol = Producto(id: 3, nombre: 'Anillo trébol', precioVenta: 1100);

// Corazones de las tarjetas (la barra inferior también usa el ícono relleno).
final _corazones = find.descendant(of: find.byType(TarjetaProducto), matching: find.byIcon(Icons.favorite_rounded));

Future<void> _abrir(WidgetTester tester, _ServicioFalso servicio) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => FavoritosProvider(servicio),
      child: MaterialApp(theme: AppTheme.oscuro(), home: const FavoritosScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Muestra las piezas guardadas con corazón, estrellas y sus etiquetas (7a)', (tester) async {
    await _abrir(tester, _ServicioFalso([_anillo, _aretes, _trebol]));

    expect(find.text('TU SELECCIÓN'), findsOneWidget);
    expect(find.text('3 piezas guardadas'), findsOneWidget);
    expect(find.text('Anillo flor rosa'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    // Las que aún no tienen reseñas muestran 0.
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Personalizable'), findsOneWidget);
    expect(find.text('Agotado'), findsOneWidget);
    // El corazón relleno en rosa marca cada pieza como favorita.
    expect(_corazones, findsNWidgets(3));
  });

  testWidgets('Tocar el corazón quita la pieza de la lista', (tester) async {
    final servicio = _ServicioFalso([_anillo, _aretes]);
    await _abrir(tester, servicio);

    await tester.tap(_corazones.first);
    await tester.pumpAndSettle();

    expect(servicio.alternadas, [1]);
    expect(find.text('Anillo flor rosa'), findsNothing);
    expect(find.text('1 pieza guardada'), findsOneWidget);
    expect(find.text('Quitada de tus favoritos'), findsOneWidget);
  });

  testWidgets('Sin favoritos invita a ver el catálogo (7c)', (tester) async {
    await _abrir(tester, _ServicioFalso([]));

    expect(find.text('Aún no tienes favoritos'), findsOneWidget);
    expect(find.text('Ver catálogo'), findsOneWidget);
  });

  testWidgets('Sin sesión pide iniciar sesión (7d)', (tester) async {
    await _abrir(tester, _ServicioFalso([], error: const FavoritoException('Inicia sesión', sinSesion: true)));

    expect(find.text('Inicia sesión para ver tus favoritos'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('Sin conexión permite reintentar y luego muestra las piezas (7e)', (tester) async {
    final servicio = _ServicioFalso([_anillo], error: const FavoritoException('Sin red'));
    await _abrir(tester, servicio);
    expect(find.text('Sin conexión'), findsOneWidget);

    servicio.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Anillo flor rosa'), findsOneWidget);
  });
}
