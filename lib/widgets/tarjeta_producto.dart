import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import 'foto_red.dart';

// Tarjeta del catálogo y de favoritos (bocetos P6 y 4b): foto de 168 px con
// el corazón arriba a la derecha y debajo nombre, precio y estrellas.
class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({super.key, required this.producto, this.onTap, this.favorita = false, this.onFavorito});

  final Producto producto;
  final VoidCallback? onTap;
  final bool favorita;
  // Sin él no se muestra el corazón.
  final VoidCallback? onFavorito;

  static const altoFoto = 170.0;
  // Foto + nombre + precio; lo usa la cuadrícula para dar el alto de cada tarjeta.
  static const alto = altoFoto + 108;

  // Categoría y material debajo del nombre ("Anillos · Plata .925").
  String? get _detalle {
    final partes = [producto.categoriaNombre, producto.material].whereType<String>().map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (partes.isEmpty) return null;
    final primera = partes.first;
    partes[0] = primera[0].toUpperCase() + primera.substring(1);
    return partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: AppColors.sombra, blurRadius: 40, offset: Offset(0, 18), spreadRadius: -12)],
      ),
      child: Material(
        color: AppColors.tarjeta,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: AppColors.borde),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Boceto P6/P7: foto grande a las orillas, con un velo oscuro abajo para las etiquetas.
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Foto(url: producto.imagen, apagada: producto.agotado),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0x00000000), Color(0x8C000000)],
                          stops: [0, 0.55, 1],
                        ),
                      ),
                    ),
                    if (!producto.agotado && (producto.tieneDescuento || producto.personalizable))
                      Positioned(
                        top: 10,
                        left: 10,
                        right: onFavorito != null ? 50 : 10,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (producto.tieneDescuento) _Pildora(texto: _descuento, degradado: true),
                            if (producto.personalizable) const _EtiquetaPersonalizable(),
                          ],
                        ),
                      ),
                    // Estado de la pieza con el color de las píldoras de Mis apartados (P12).
                    if (_estado != null) Positioned(left: 10, bottom: 10, child: _estado!),
                    if (producto.agotado) const Center(child: _Agotado()),
                    if (onFavorito != null)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: _Corazon(favorita: favorita, onTap: onFavorito!),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.texto, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                    ),
                    if (_detalle != null) ...[
                      const SizedBox(height: 5),
                      // Píldora rosa como la categoría en el carrito (P9).
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          _detalle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.primario, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Precio en etiqueta colgante, como en el detalle de la web.
                              _EtiquetaPrecio(texto: formatoPrecio(producto.precioFinal)),
                              const SizedBox(height: 3),
                              if (producto.tieneDescuento)
                                Text(
                                  formatoPrecio(producto.precioVenta),
                                  style: TextStyle(color: AppColors.textoSuave, fontSize: 10.5, decoration: TextDecoration.lineThrough),
                                )
                              else
                                _Estrellas(promedio: producto.promedioResenas),
                            ],
                          ),
                        ),
                        // Botón con la flecha, como el del banner del Inicio (P5).
                        ExcludeSemantics(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: producto.agotado ? null : AppColors.degradado,
                              color: producto.agotado ? AppColors.superficie2 : null,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.arrow_outward_rounded, size: 17, color: producto.agotado ? AppColors.textoSuave : Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _descuento => '-${((1 - producto.precioFinal / producto.precioVenta) * 100).round()}%';

  // Nuevo (verde, como "Al corriente") o Quedan N (naranja, como "2 días").
  Widget? get _estado {
    if (producto.agotado) return null;
    // El mismo límite que el detalle de la pieza: "Quedan N" con 5 o menos.
    if (producto.stock <= 5) return _Estado(texto: 'Quedan ${producto.stock}', icono: Icons.local_fire_department_rounded, color: const Color(0xFFFFB547));
    if (producto.esNuevo) return const _Estado(texto: 'Nuevo', icono: Icons.auto_awesome_rounded, color: Color(0xFF4ADE80));
    return null;
  }
}

// Píldora de estado: fondo oscuro translúcido y texto del color del estado.
class _Estado extends StatelessWidget {
  const _Estado({required this.texto, required this.icono, required this.color});
  final String texto;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.18), const Color(0xCC14080F)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            texto,
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({this.url, required this.apagada});
  final String? url;
  final bool apagada;

  // grayscale(.8) brightness(.7) del boceto para las piezas agotadas.
  static const _gris = ColorFilter.matrix([
    0.26, 0.40, 0.04, 0, 0, //
    0.12, 0.54, 0.04, 0, 0, //
    0.12, 0.40, 0.18, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    // Si está agotada la píldora ocupa el centro; el diamante se encimaría.
    final sinFoto = ColoredBox(
      color: AppColors.superficie2,
      child: apagada ? null : Center(child: Icon(Icons.diamond_outlined, size: 40, color: AppColors.textoSuave)),
    );
    final Widget foto = (url == null || url!.isEmpty)
        ? sinFoto
        : FotoRed(
            url!,
            error: sinFoto,
            cargando: ColoredBox(color: AppColors.superficie2),
          );
    return apagada ? ColorFiltered(colorFilter: _gris, child: foto) : foto;
  }
}

// Calificación junto al precio (★ 4.9); en 0 mientras no haya reseñas.
class _Estrellas extends StatelessWidget {
  const _Estrellas({required this.promedio});
  final double promedio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Calificación ${formatoCalificacion(promedio)}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF6A723)),
          const SizedBox(width: 2),
          Text(formatoCalificacion(promedio), style: TextStyle(color: AppColors.textoSuave, fontSize: 11)),
        ],
      ),
    );
  }
}

// Botón de vidrio con el corazón (.gbtn.glass de 34 px): rosa relleno si es favorita.
class _Corazon extends StatelessWidget {
  const _Corazon({required this.favorita, required this.onTap});
  final bool favorita;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: favorita,
      label: favorita ? 'Quitar de favoritos' : 'Guardar en favoritos',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: favorita ? Colors.white : AppColors.cristal,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: favorita ? Colors.white : AppColors.cristalBorde),
          ),
          // Boceto P7: favorita en cuadro blanco con el corazón rosa.
          child: Icon(favorita ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 17, color: favorita ? AppColors.primario : Colors.white),
        ),
      ),
    );
  }
}

class _EtiquetaPersonalizable extends StatelessWidget {
  const _EtiquetaPersonalizable();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xE6FFFFFF), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.brush_rounded, size: 13, color: AppColors.acentoOscuro),
          const SizedBox(width: 4),
          Text(
            'Personalizable',
            style: TextStyle(color: AppColors.acentoOscuro, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Píldora del descuento sobre la foto, con el degradado de la marca.
class _Pildora extends StatelessWidget {
  const _Pildora({required this.texto, this.degradado = false});
  final String texto;
  final bool degradado;

  @override
  Widget build(BuildContext context) {
    final color = degradado ? Colors.white : AppColors.acentoOscuro;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: degradado ? AppColors.degradado : null,
        color: degradado ? null : const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Agotado extends StatelessWidget {
  const _Agotado();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(20)),
      child: const Text(
        'Agotado',
        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Etiqueta de precio colgando de su hilo (web: .pdp-precios), con el agujero a la izquierda.
class _EtiquetaPrecio extends StatelessWidget {
  const _EtiquetaPrecio({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 2),
      child: Transform.rotate(
        angle: -0.044,
        alignment: Alignment.topLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 3, 10, 4),
              decoration: BoxDecoration(
                color: AppColors.suave,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border.all(color: AppColors.primario.withValues(alpha: 0.35)),
                boxShadow: [BoxShadow(color: AppColors.sombra, blurRadius: 10, offset: const Offset(0, 4), spreadRadius: -4)],
              ),
              child: Text(
                texto,
                style: TextStyle(color: AppColors.primario, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              ),
            ),
            // Agujero de la etiqueta.
            Positioned(
              left: 7,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.tarjeta,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primario.withValues(alpha: 0.6), width: 1.2),
                  ),
                ),
              ),
            ),
            // Hilo que sale del agujero.
            Positioned(
              left: 9,
              top: -9,
              child: Transform.rotate(
                angle: -0.25,
                child: Container(width: 1.4, height: 18, color: AppColors.primario.withValues(alpha: 0.55)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
