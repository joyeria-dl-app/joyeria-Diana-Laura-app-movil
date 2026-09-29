import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../services/producto_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/decoracion.dart';
import '../widgets/galeria_fotos.dart';

// Color de "Quedan N" en los bocetos (--warn).
const _aviso = Color(0xFFF6A723);

// Detalle de una pieza (boceto P7 y estados 5a–5e de Bocetos_Sprint2).
class DetalleScreen extends StatefulWidget {
  const DetalleScreen({super.key, required this.productoId});

  final int productoId;

  @override
  State<DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<DetalleScreen> {
  DetalleProducto? _detalle;
  ProductoException? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final detalle = await context.read<ProductoService>().detalle(widget.productoId);
      if (mounted) setState(() => _detalle = detalle);
    } on ProductoException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  // Corazón, compartir, tallas y Agregar se conectan en HU-09, HU-10 y HU-13.
  void _pronto() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Disponible muy pronto')));
  }

  @override
  Widget build(BuildContext context) {
    final altoFoto = (MediaQuery.sizeOf(context).height * 0.5).clamp(300.0, 420.0);
    final detalle = _detalle;
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: altoFoto,
            child: (detalle != null && detalle.imagenes.length > 1)
                ? GaleriaFotos(
                    imagenes: detalle.imagenes,
                    topMiniaturas: altoFoto * 0.48,
                    foto: (url) => _Foto(url: url, cargando: false, apagada: detalle.producto.agotado),
                  )
                : _Foto(url: detalle?.imagenes.firstOrNull, cargando: detalle == null, apagada: detalle?.producto.agotado ?? false),
          ),
          Positioned(
            top: altoFoto - 40,
            left: 0,
            right: 0,
            bottom: 0,
            child: _Hoja(
              child: switch ((detalle, _error)) {
                (_, final ProductoException error) when error.noEncontrado => _Aviso(
                    icono: Icons.search_off_rounded,
                    titulo: 'Pieza no disponible',
                    texto: 'Esta pieza ya no está disponible. Puede que se haya vendido o retirado del catálogo.',
                    boton: 'Ver catálogo',
                    iconoBoton: Icons.diamond_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                (_, ProductoException _) => _Aviso(
                    icono: Icons.wifi_off_rounded,
                    titulo: 'Sin conexión',
                    texto: 'No se pudo cargar la pieza. Revisa tu conexión e intenta de nuevo.',
                    boton: 'Reintentar',
                    iconoBoton: Icons.refresh_rounded,
                    onPressed: _cargar,
                  ),
                (final DetalleProducto d, _) => _Contenido(detalle: d, onPronto: _pronto),
                _ => const _Cargando(),
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    _BotonFoto(icono: Icons.arrow_back_rounded, descripcion: 'Regresar', onTap: () => Navigator.pop(context)),
                    const Spacer(),
                    _BotonFoto(icono: Icons.ios_share_rounded, descripcion: 'Compartir', onTap: _pronto),
                    const SizedBox(width: 8),
                    _BotonFoto(icono: Icons.favorite_rounded, descripcion: 'Agregar a favoritos', onTap: _pronto, blanco: true),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({this.url, required this.cargando, required this.apagada});
  final String? url;
  final bool cargando;
  final bool apagada;

  static const _gris = ColorFilter.matrix([
    0.26, 0.40, 0.04, 0, 0, //
    0.12, 0.54, 0.04, 0, 0, //
    0.12, 0.40, 0.18, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    // Boceto 5c: sin foto se ve un diamante al centro.
    final sinFoto = ColoredBox(
      color: AppColors.superficie2,
      child: cargando ? null : const Center(child: Icon(Icons.diamond_outlined, size: 64, color: AppColors.primario)),
    );
    final Widget foto = (url == null)
        ? sinFoto
        : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => sinFoto);
    return Stack(
      fit: StackFit.expand,
      children: [
        apagada ? ColorFiltered(colorFilter: _gris, child: foto) : foto,
        // Sombra arriba para que se lean la hora y los botones.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x59000000), Color(0x00000000)],
              stops: [0, 0.3],
            ),
          ),
        ),
      ],
    );
  }
}

// Botones sobre la foto: vidrio blanco translúcido; el corazón va en blanco sólido.
class _BotonFoto extends StatelessWidget {
  const _BotonFoto({required this.icono, required this.descripcion, required this.onTap, this.blanco = false});
  final IconData icono;
  final String descripcion;
  final VoidCallback onTap;
  final bool blanco;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: descripcion,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: blanco ? Colors.white : const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(16),
                border: blanco ? null : Border.all(color: const Color(0x4DFFFFFF)),
              ),
              child: Icon(icono, size: 20, color: blanco ? const Color(0xFFE0679A) : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// Hoja redondeada que sube sobre la foto, con la rayita de arriba.
class _Hoja extends StatelessWidget {
  const _Hoja({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.fondo,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 40, offset: Offset(0, -20))],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(3)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.detalle, required this.onPronto});
  final DetalleProducto detalle;
  final VoidCallback onPronto;

  @override
  Widget build(BuildContext context) {
    final p = detalle.producto;
    final datos = [
      // En el panel algunas categorías se capturaron en minúsculas ("esclavas").
      if (p.categoriaNombre case final c? when c.isNotEmpty) c[0].toUpperCase() + c.substring(1),
      ?p.material,
      if (detalle.pesoGramos case final peso?) '${peso.toStringAsFixed(1)} g',
    ];
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (p.agotado) const _Etiqueta(texto: 'Agotado', fondo: Color(0x8C000000), color: Colors.white),
                  if (p.personalizable && !p.agotado)
                    const _Etiqueta(texto: 'Personalizable', icono: Icons.brush_rounded, fondo: AppColors.suave, color: AppColors.primario),
                  if (!p.agotado && p.stock <= 5)
                    _Etiqueta(
                      texto: 'Quedan ${p.stock}',
                      icono: Icons.local_fire_department_rounded,
                      fondo: const Color(0x26F6A723),
                      color: _aviso,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                p.nombre,
                style: const TextStyle(color: AppColors.texto, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1),
              ),
              if (datos.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.diamond_rounded, size: 13, color: AppColors.primario),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(datos.join(' · '), style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                p.agotado
                    ? 'Por ahora no hay piezas disponibles. Vuelve pronto o mira otras joyas del catálogo.'
                    : (detalle.descripcion?.trim().isNotEmpty ?? false)
                        ? detalle.descripcion!.trim()
                        : 'Pieza de la colección Diana Laura.',
                style: const TextStyle(color: AppColors.textoSuave, fontSize: 12.5, height: 1.55),
              ),
              // La talla solo aparece si la pieza la tiene registrada.
              if (detalle.medidas case final medida?) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Talla', style: TextStyle(color: AppColors.texto, fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: onPronto,
                      child: const Text('Guía de tallas', style: TextStyle(color: AppColors.primario, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.degradado,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [BoxShadow(color: Color(0x80CF819F), blurRadius: 18, offset: Offset(0, 8), spreadRadius: -8)],
                    ),
                    child: Text(medida, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
        _BarraPrecio(producto: p, onAgregar: onPronto),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.fondo, required this.color, this.icono});
  final String texto;
  final Color fondo;
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 13, color: color), const SizedBox(width: 4)],
          Text(texto, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Barra de vidrio con el precio y el botón Agregar (o Agotado).
class _BarraPrecio extends StatelessWidget {
  const _BarraPrecio({required this.producto, required this.onAgregar});
  final Producto producto;
  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0x8C281224),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x2EFFAAD7)),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 20), spreadRadius: -10)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Precio', style: TextStyle(color: AppColors.textoSuave, fontSize: 11)),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatoPrecio(producto.precioFinal),
                          style: const TextStyle(color: AppColors.texto, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                        ),
                        const TextSpan(text: ' MXN', style: TextStyle(color: AppColors.textoSuave, fontSize: 11, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  if (producto.tieneDescuento)
                    Text(
                      formatoPrecio(producto.precioVenta),
                      style: const TextStyle(color: AppColors.textoSuave, fontSize: 11, decoration: TextDecoration.lineThrough),
                    ),
                ],
              ),
            ),
            producto.agotado
                ? Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      children: [
                        Icon(Icons.block_rounded, size: 18, color: AppColors.textoSuave),
                        SizedBox(width: 8),
                        Text('Agotado', style: TextStyle(color: AppColors.textoSuave, fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : _BotonDegradado(texto: 'Agregar', icono: Icons.shopping_bag_outlined, onPressed: onAgregar, alto: 54, radio: 20),
          ],
        ),
      ),
    );
  }
}

class _BotonDegradado extends StatelessWidget {
  const _BotonDegradado({required this.texto, required this.icono, required this.onPressed, this.alto = 50, this.radio = 18, this.ancho});
  final String texto;
  final IconData icono;
  final VoidCallback onPressed;
  final double alto;
  final double radio;
  final double? ancho;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.degradado,
        borderRadius: BorderRadius.circular(radio),
        boxShadow: const [BoxShadow(color: Color(0x80CF819F), blurRadius: 30, offset: Offset(0, 16), spreadRadius: -12)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(radio),
          onTap: onPressed,
          child: SizedBox(
            height: alto,
            width: ancho,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ancho == null ? 22 : 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icono, size: 19, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      texto,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Boceto 5b.
class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    Widget barra(double ancho, double alto) => FractionallySizedBox(
          widthFactor: ancho,
          alignment: Alignment.centerLeft,
          child: Container(
            height: alto,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(alto / 2)),
          ),
        );
    return Semantics(
      label: 'Cargando la pieza',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [barra(0.3, 20), barra(0.75, 24), barra(0.4, 12), const SizedBox(height: 6), barra(1, 12), barra(0.85, 12)],
        ),
      ),
    );
  }
}

// Bocetos 5d y 5e: el aviso va dentro de la hoja.
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 30),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(30)),
            child: Icon(icono, size: 40, color: AppColors.primario),
          ),
          const SizedBox(height: 18),
          Text(titulo, style: const TextStyle(color: AppColors.texto, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSuave, fontSize: 13)),
          ),
          const SizedBox(height: 22),
          _BotonDegradado(texto: boton, icono: iconoBoton, onPressed: onPressed, ancho: 210),
        ],
      ),
    );
  }
}
