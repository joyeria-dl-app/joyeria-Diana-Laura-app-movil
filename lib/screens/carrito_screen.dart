import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/carrito.dart';
import '../providers/carrito_provider.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/decoracion.dart';
import '../widgets/resumen_carrito.dart';

// Color de "Solo quedan N" en los bocetos (--warn).
const _aviso = Color(0xFFF6A723);

// Carrito del cliente (boceto P9 y estados 6a–6g de Bocetos_Sprint2).
class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  // Hasta la primera respuesta se muestran las tarjetas vacías (6b).
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    // Se pide al abrir para traer lo que el cliente haya agregado en el sitio web.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CarritoProvider>().cargar();
      if (mounted) setState(() => _listo = true);
    });
  }

  void _mostrar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // Después de cambiar algo, el backend puede rechazarlo (por ejemplo, sin existencias).
  Future<void> _tras(Future<bool> accion) async {
    final carrito = context.read<CarritoProvider>();
    final ok = await accion;
    if (!ok && mounted && carrito.aviso != null) _mostrar(carrito.aviso!);
  }

  // Boceto 6f.
  Future<void> _confirmarVaciar(int piezas) async {
    final vaciar = await showModalBottomSheet<bool>(
      context: context,
      // Sin esto la hoja se limita a 9/16 de la pantalla y en teléfonos bajos no cabe.
      isScrollControlled: true,
      backgroundColor: AppColors.fondo,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => _ConfirmarVaciar(piezas: piezas),
    );
    if (vaciar == true && mounted) await _tras(context.read<CarritoProvider>().vaciar());
  }

  @override
  Widget build(BuildContext context) {
    final carrito = context.watch<CarritoProvider>();
    final items = carrito.items;
    final conPiezas = items.isNotEmpty;
    final piezas = carrito.piezas;
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          const Destellos(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Encabezado(
                  antetitulo: (!_listo || carrito.cargando) && !conPiezas
                      ? null
                      : carrito.sinSesion || (carrito.error != null && !conPiezas)
                          ? 'Carrito'
                          : '$piezas ${piezas == 1 ? 'pieza' : 'piezas'}',
                  onVaciar: conPiezas ? () => _confirmarVaciar(piezas) : null,
                ),
                Expanded(child: _contenido(carrito)),
              ],
            ),
          ),
          Positioned(
            left: conPiezas ? 0 : 16,
            right: conPiezas ? 0 : 16,
            bottom: conPiezas ? 0 : 16,
            // Con piezas, la barra de navegación se cambia por el total (6a).
            child: conPiezas
                ? BarraPagar(total: carrito.total, onPagar: () => _mostrar('Disponible muy pronto'))
                : const SafeArea(top: false, child: BarraNavegacion(actual: Seccion.carrito)),
          ),
        ],
      ),
    );
  }

  Widget _contenido(CarritoProvider carrito) {
    final items = carrito.items;
    // 6b.
    if ((!_listo || carrito.cargando) && items.isEmpty) return const _Cargando();
    // 6d.
    if (carrito.sinSesion) {
      return _Aviso(
        icono: Icons.lock_outline_rounded,
        titulo: 'Inicia sesión para usar tu carrito',
        texto: 'Con tu cuenta, el carrito de la app es el mismo que ves en el sitio web.',
        boton: 'Iniciar sesión',
        iconoBoton: Icons.login_rounded,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
      );
    }
    // 6e.
    if (carrito.error != null && items.isEmpty) {
      return _Aviso(
        icono: Icons.wifi_off_rounded,
        titulo: 'Sin conexión',
        texto: 'No se pudo cargar tu carrito. Revisa tu conexión e intenta de nuevo.',
        boton: 'Reintentar',
        iconoBoton: Icons.refresh_rounded,
        onPressed: carrito.cargar,
      );
    }
    // 6c.
    if (items.isEmpty) {
      return _Aviso(
        icono: Icons.shopping_bag_outlined,
        titulo: 'Tu carrito está vacío',
        texto: 'Agrega piezas desde el catálogo y aquí verás el total de tu compra.',
        boton: 'Ver catálogo',
        iconoBoton: Icons.diamond_outlined,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.catalogo),
      );
    }
    // 6a y 6g.
    return RefreshIndicator(
      color: AppColors.primario,
      onRefresh: carrito.cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: [
          for (final item in items) ...[
            _PiezaDeslizable(
              item: item,
              onMenos: () => _tras(carrito.cambiarCantidad(item, item.cantidad - 1)),
              onMas: () => _tras(carrito.cambiarCantidad(item, item.cantidad + 1)),
              onQuitar: () => _tras(carrito.quitar(item)),
            ),
            if (item.cantidad >= item.stock) _SinExistencias(stock: item.stock),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 2),
          ResumenCarrito(subtotal: carrito.subtotal, total: carrito.total),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.antetitulo, required this.onVaciar});
  // Nulo mientras carga (6b).
  final String? antetitulo;
  final VoidCallback? onVaciar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: antetitulo == null
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_Barra(ancho: 60, alto: 10), SizedBox(height: 8), _Barra(ancho: 150, alto: 26)],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Antetitulo(antetitulo!), const SizedBox(height: 2), const TituloDegradado('Tu carrito', tamano: 28)],
                  ),
          ),
          if (onVaciar != null) BotonCristal(icono: Icons.delete_sweep_outlined, descripcion: 'Vaciar carrito', onPressed: onVaciar!),
        ],
      ),
    );
  }
}

// Al deslizar a la izquierda aparece el rojo con el bote de basura (6a).
class _PiezaDeslizable extends StatelessWidget {
  const _PiezaDeslizable({required this.item, required this.onMenos, required this.onMas, required this.onQuitar});
  final ItemCarrito item;
  final VoidCallback onMenos;
  final VoidCallback onMas;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onQuitar(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, AppColors.error], stops: [0.4, 1]),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        child: _Pieza(item: item, onMenos: onMenos, onMas: onMas),
      ),
    );
  }
}

class _Pieza extends StatelessWidget {
  const _Pieza({required this.item, required this.onMenos, required this.onMas});
  final ItemCarrito item;
  final VoidCallback onMenos;
  final VoidCallback onMas;

  @override
  Widget build(BuildContext context) {
    final etiqueta = item.talla ?? item.categoriaNombre;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 90,
              height: 90,
              child: item.imagen == null
                  ? const _SinFoto()
                  : Image.network(item.imagen!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _SinFoto()),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (etiqueta != null && etiqueta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  // En el panel algunas categorías se capturaron en minúsculas ("esclavas").
                  Etiqueta(etiqueta[0].toUpperCase() + etiqueta.substring(1)),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatoPrecio(item.precioFinal),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                      ),
                    ),
                    _Cantidad(cantidad: item.cantidad, onMenos: onMenos, onMas: item.puedeAumentar ? onMas : null),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Control .qty del boceto: − cantidad +.
class _Cantidad extends StatelessWidget {
  const _Cantidad({required this.cantidad, required this.onMenos, required this.onMas});
  final int cantidad;
  final VoidCallback onMenos;
  // Nulo cuando ya no hay más existencias.
  final VoidCallback? onMas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BotonCantidad(icono: Icons.remove_rounded, descripcion: 'Quitar una', color: AppColors.texto, onTap: onMenos),
          Text('$cantidad', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          _BotonCantidad(
            icono: Icons.add_rounded,
            descripcion: 'Agregar una',
            color: onMas == null ? AppColors.textoSuave.withValues(alpha: 0.4) : AppColors.primario,
            onTap: onMas,
          ),
        ],
      ),
    );
  }
}

class _BotonCantidad extends StatelessWidget {
  const _BotonCantidad({required this.icono, required this.descripcion, required this.color, required this.onTap});
  final IconData icono;
  final String descripcion;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: descripcion,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(width: 32, height: 32, child: Icon(icono, size: 18, color: color)),
      ),
    );
  }
}

// Boceto 6g.
class _SinExistencias extends StatelessWidget {
  const _SinExistencias({required this.stock});
  final int stock;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: const Color(0x26F6A723), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: _aviso),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              stock == 1 ? 'Solo queda 1 pieza disponible.' : 'Solo quedan $stock piezas disponibles.',
              style: const TextStyle(color: _aviso, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _SinFoto extends StatelessWidget {
  const _SinFoto();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: AppColors.superficie2, child: Center(child: Icon(Icons.diamond_outlined, color: AppColors.textoSuave)));
}

class _Barra extends StatelessWidget {
  const _Barra({required this.ancho, required this.alto});
  final double ancho;
  final double alto;

  @override
  Widget build(BuildContext context) => Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(alto / 2)),
      );
}

// Boceto 6b: tarjetas vacías mientras llega el carrito.
class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    Widget tarjeta() => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.superficie,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borde),
          ),
          child: Row(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(20)),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_Barra(ancho: 120, alto: 14), SizedBox(height: 8), _Barra(ancho: 70, alto: 12), SizedBox(height: 14), _Barra(ancho: 90, alto: 16)],
              ),
            ],
          ),
        );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      children: [tarjeta(), tarjeta()],
    );
  }
}

// Estados 6c, 6d y 6e: cuadro rosa suave con ícono, título y botón.
class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.iconoBoton,
    required this.onPressed,
  });
  final IconData icono;
  final String titulo;
  final String texto;
  final String boton;
  final IconData iconoBoton;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(30)),
            child: Icon(icono, size: 40, color: AppColors.primario),
          ),
          const SizedBox(height: 18),
          Text(titulo, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.texto, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSuave, fontSize: 13)),
          ),
          const SizedBox(height: 22),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.degradado,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x80CF819F), blurRadius: 30, offset: Offset(0, 16), spreadRadius: -12)],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onPressed,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 210),
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(iconoBoton, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(boton, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Boceto 6f: hoja inferior para confirmar antes de vaciar.
class _ConfirmarVaciar extends StatelessWidget {
  const _ConfirmarVaciar({required this.piezas});
  final int piezas;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.delete_sweep_outlined, size: 32, color: AppColors.error),
              ),
            ),
            const SizedBox(height: 14),
            const Text('¿Vaciar el carrito?', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Se quitarán ${piezas == 1 ? 'la pieza' : 'las $piezas piezas'}. También se vacía en el sitio web.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Vaciar carrito', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.superficie2,
                foregroundColor: AppColors.texto,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
