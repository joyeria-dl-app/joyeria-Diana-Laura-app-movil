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

  Future<void> cargar() async {
    cargando = true;
    sinConexion = false;
    notifyListeners();
    final (c, b, d) = await (_opcional(_productos.categorias), _opcional(_inicio.carrusel), _opcional(_destacadas)).wait;
    categorias = c ?? const [];
    banners = b ?? const [];
    destacadas = d ?? const [];
    sinConexion = c == null && b == null && d == null;
    cargando = false;
    notifyListeners();
  }

  // La primera página del catálogo, primero las que tienen existencias.
  Future<List<Producto>> _destacadas() async {
    final piezas = await _productos.productos();
    final conExistencias = piezas.where((p) => !p.agotado);
    return [...conExistencias, ...piezas.where((p) => p.agotado)].take(maxDestacadas).toList();
  }

  Future<T?> _opcional<T>(Future<T> Function() consulta) async {
    try {
      return await consulta();
    } on Object {
      return null;
    }
  }
}
