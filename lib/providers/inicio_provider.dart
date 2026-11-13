import 'package:flutter/foundation.dart';

import '../models/banner_inicio.dart';
import '../models/producto.dart';
import '../services/inicio_service.dart';
import '../services/producto_service.dart';

// Estado del Inicio (#244): categorías, banners del carrusel y piezas destacadas. Cada parte se
// pide por separado; si una falla, el Inicio se ve sin ella en lugar de mostrar un error.
class InicioProvider extends ChangeNotifier {
  InicioProvider({required this._productos, required this._inicio});

  final ProductoService _productos;
  final InicioService _inicio;

  // Piezas que se muestran en "Para ti".
  static const maxDestacadas = 10;

  List<Categoria> categorias = const [];
  List<BannerInicio> banners = const [];
  List<Producto> destacadas = const [];
  bool cargando = false;
  // Las tres consultas fallaron: no hay nada que mostrar y se ofrece reintentar.
  bool sinConexion = false;
  // Si el Inicio se cierra antes de que lleguen las respuestas, ya no se avisa (#93).
  bool _cerrado = false;

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }

  Future<void> cargar() async {
    cargando = true;
    sinConexion = false;
    notifyListeners();
    final (c, b, d) = await (_opcional(_productos.categorias), _opcional(_inicio.carrusel), _opcional(_destacadas)).wait;
    if (_cerrado) return;
    categorias = c ?? const [];
    banners = b ?? const [];
    destacadas = d ?? const [];
    sinConexion = c == null && b == null && d == null;
    cargando = false;
    notifyListeners();
  }

  // Hasta cuántas páginas del catálogo se revisan para llenar "Para ti" con piezas disponibles.
  static const paginasParaTi = 3;
  // Con menos de estas piezas disponibles se sigue buscando en la página siguiente.
  static const minimoDisponibles = 4;

  // Solo piezas con existencias: se revisan las primeras páginas del catálogo hasta juntar
  // suficientes. Si no hay ninguna disponible se muestran las agotadas para no dejar la sección vacía.
  Future<List<Producto>> _destacadas() async {
    final vistas = <int>{};
    final disponibles = <Producto>[];
    final agotadas = <Producto>[];
    for (var pagina = 0; pagina < paginasParaTi; pagina++) {
      final piezas = await _productos.productos(pagina: pagina);
      var nuevas = 0;
      for (final p in piezas) {
        if (!vistas.add(p.id)) continue;
        nuevas++;
        (p.agotado ? agotadas : disponibles).add(p);
      }
      if (disponibles.length >= minimoDisponibles || nuevas == 0 || piezas.length < ProductoService.porPagina) break;
    }
    return (disponibles.isNotEmpty ? disponibles : agotadas).take(maxDestacadas).toList();
  }

  Future<T?> _opcional<T>(Future<T> Function() consulta) async {
    try {
      return await consulta();
    } on Object {
      return null;
    }
  }
}
