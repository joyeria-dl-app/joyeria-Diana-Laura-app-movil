import 'package:flutter/foundation.dart';

import '../models/carrito.dart';
import '../services/carrito_service.dart';

// Estado del carrito para la pantalla P9. Cada cambio se manda al backend y
// después se vuelve a pedir el carrito, para que siempre coincida con el del sitio web.
class CarritoProvider extends ChangeNotifier {
  CarritoProvider(this._service);

  final CarritoService _service;

  Carrito _carrito = const Carrito();
  bool _cargando = false;
  bool _sinSesion = false;
  String? _error;
  // Aviso corto tras una acción que falló, por ejemplo "Stock insuficiente".
  String? _aviso;

  Carrito get carrito => _carrito;
  List<ItemCarrito> get items => _carrito.items;
  bool get cargando => _cargando;
  bool get sinSesion => _sinSesion;
  String? get error => _error;
  String? get aviso => _aviso;
  int get piezas => _carrito.piezas;

  // Mismo cálculo que el backend: precio final (promoción, oferta o venta) por cantidad.
  // Se calcula aquí para que el total cambie en cuanto se toca + o −.
  double get subtotal => items.fold(0, (suma, i) => suma + i.precioFinal * i.cantidad);
  // El envío se calcula al pagar (HU-12), así que por ahora el total es el subtotal.
  double get total => subtotal;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _carrito = await _service.obtener();
      _sinSesion = false;
    } on CarritoException catch (e) {
      _sinSesion = e.sinSesion;
      _error = e.sinSesion ? null : e.mensaje;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> agregar(int productoId, {int cantidad = 1, String? talla}) => _cambiar(() => _service.agregar(productoId, cantidad: cantidad, talla: talla));

  Future<bool> cambiarCantidad(ItemCarrito item, int cantidad) {
    if (cantidad < 1) return quitar(item);
    // El total se actualiza al momento; si el backend lo rechaza, se recarga el real.
    _reemplazar(item, cantidad: cantidad);
    return _cambiar(() => _service.cambiarCantidad(item.id, cantidad));
  }

  Future<bool> quitar(ItemCarrito item) {
    _carrito = Carrito(items: items.where((i) => i.id != item.id).toList());
    notifyListeners();
    return _cambiar(() => _service.quitar(item.id));
  }

  Future<bool> vaciar() {
    _carrito = const Carrito();
    notifyListeners();
    return _cambiar(_service.vaciar);
  }

  void limpiarAviso() => _aviso = null;

  Future<bool> _cambiar(Future<void> Function() accion) async {
    _aviso = null;
    var ok = true;
    try {
      await accion();
    } on CarritoException catch (e) {
      ok = false;
      _aviso = e.mensaje;
      _sinSesion = e.sinSesion;
    }
    try {
      _carrito = await _service.obtener();
    } on CarritoException catch (e) {
      _aviso ??= e.mensaje;
    }
    notifyListeners();
    return ok;
  }

  void _reemplazar(ItemCarrito item, {required int cantidad}) {
    _carrito = Carrito(
      items: [
        for (final i in items)
          i.id == item.id
              ? ItemCarrito(
                  id: i.id,
                  productoId: i.productoId,
                  nombre: i.nombre,
                  cantidad: cantidad,
                  precioVenta: i.precioVenta,
                  precioOferta: i.precioOferta,
                  precioPromocion: i.precioPromocion,
                  imagen: i.imagen,
                  talla: i.talla,
                  categoriaNombre: i.categoriaNombre,
                  stock: i.stock,
                )
              : i,
      ],
    );
    notifyListeners();
  }
}
