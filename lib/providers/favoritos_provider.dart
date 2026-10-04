import 'package:flutter/foundation.dart';

import '../models/producto.dart';
import '../services/favorito_service.dart';

// Favoritos del cliente para el corazón del catálogo y del detalle y para la
// pantalla 4b. Se guardan en el backend, así que son los mismos del sitio web.
class FavoritosProvider extends ChangeNotifier {
  FavoritosProvider(this._service);

  final FavoritoService _service;

  List<Producto> _lista = [];
  final Set<int> _ids = {};
  bool _cargando = false;
  bool _cargada = false;
  bool _sinSesion = false;
  String? _error;

  List<Producto> get lista => _lista;
  bool get cargando => _cargando;
  // Ya llegó al menos una respuesta del backend.
  bool get cargada => _cargada;
  bool get sinSesion => _sinSesion;
  String? get error => _error;

  bool esFavorita(int productoId) => _ids.contains(productoId);

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _lista = await _service.lista();
      _ids
        ..clear()
        ..addAll(_lista.map((p) => p.id));
      _sinSesion = false;
    } on FavoritoException catch (e) {
      _sinSesion = e.sinSesion;
      _error = e.sinSesion ? null : e.mensaje;
    } finally {
      _cargando = false;
      _cargada = true;
      notifyListeners();
    }
  }

  // Al abrir el detalle se pregunta por esa pieza; sin sesión se queda sin marcar.
  Future<void> comprobar(int productoId) async {
    try {
      final favorita = await _service.esFavorito(productoId);
      favorita ? _ids.add(productoId) : _ids.remove(productoId);
      notifyListeners();
    } on FavoritoException {
      return;
    }
  }

  // El corazón cambia al momento; si el backend falla vuelve como estaba.
  // Devuelve cómo quedó la pieza, o null si no se pudo guardar.
  Future<bool?> alternar(Producto producto) async {
    final antes = esFavorita(producto.id);
    _marcar(producto, !antes);
    try {
      final ahora = await _service.alternar(producto.id);
      _marcar(producto, ahora);
      _sinSesion = false;
      return ahora;
    } on FavoritoException catch (e) {
      _marcar(producto, antes);
      _sinSesion = e.sinSesion;
      return null;
    }
  }

  void _marcar(Producto producto, bool favorita) {
    if (favorita) {
      _ids.add(producto.id);
      if (!_lista.any((p) => p.id == producto.id)) _lista = [producto, ..._lista];
    } else {
      _ids.remove(producto.id);
      _lista = _lista.where((p) => p.id != producto.id).toList();
    }
    notifyListeners();
  }
}
