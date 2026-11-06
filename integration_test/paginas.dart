import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:joyeria_diana_laura/models/producto.dart';
import 'package:joyeria_diana_laura/screens/catalogo_screen.dart';
import 'package:joyeria_diana_laura/services/producto_service.dart';

// El catálogo muestra páginas numeradas (#279). Estas ayudas buscan en todas las páginas, para que las
// pruebas no dependan de que la pieza buscada esté en la primera.

// Piezas de todas las páginas del servidor.
Future<List<Producto>> todasLasPiezas(ProductoService productos, {int? categoriaId}) async {
  final todas = <Producto>[];
  for (var pagina = 0; pagina < 50; pagina++) {
    final parte = await productos.productos(categoriaId: categoriaId, pagina: pagina);
    todas.addAll(parte);
    if (parte.length < ProductoService.porPagina) break;
  }
  return todas;
}

// En la pantalla del catálogo: baja hasta encontrar la tarjeta y, si no está en esta página, pasa a la
// siguiente. Devuelve true si la encontró.
Future<bool> buscarEnPaginas(WidgetTester tester, Finder buscado) async {
  final lista = find
      .descendant(of: find.byType(CatalogoScreen), matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down))
      .first;
  for (var pagina = 0; pagina < 20; pagina++) {
    for (var i = 0; i < 8 && buscado.evaluate().isEmpty; i++) {
      await tester.drag(lista, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    if (buscado.evaluate().isNotEmpty) return true;
    final siguiente = find.byKey(const Key('pagina_siguiente'));
    if (siguiente.evaluate().isEmpty || tester.widget<IconButton>(siguiente).onPressed == null) return false;
    await tester.ensureVisible(siguiente);
    await tester.tap(siguiente);
    // La página nueva llega del servidor.
    for (var i = 0; i < 20 && buscado.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
  }
  return buscado.evaluate().isNotEmpty;
}
