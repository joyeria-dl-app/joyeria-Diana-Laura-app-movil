import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';

// Tarjeta del catálogo y de favoritos (bocetos P6 y 4b): foto de 168 px con
// el corazón arriba a la derecha y debajo nombre, precio y estrellas.
class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({super.key, required this.producto, this.onTap, this.favorita = false, this.onFavorito});

  final Producto producto;
  final VoidCallback? onTap;
  final bool favorita;
  // Sin él no se muestra el corazón.
  final VoidCallback? onFavorito;

  static const altoFoto = 168.0;
  // Foto + nombre + precio; lo usa la cuadrícula para dar el alto de cada tarjeta.
  static const alto = altoFoto + 72;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0xBF000000), blurRadius: 40, offset: Offset(0, 18), spreadRadius: -12)],
      ),
      child: Material(
        color: const Color(0xFF1A0F18),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: AppColors.borde),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Foto(url: producto.imagen, apagada: producto.agotado),
                    if (producto.personalizable && !producto.agotado) const Positioned(top: 10, left: 10, child: _EtiquetaPersonalizable()),
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
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.texto, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatoPrecio(producto.precioFinal),
                          style: const TextStyle(color: AppColors.primario, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                        ),
                        if (producto.tieneDescuento) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              formatoPrecio(producto.precioVenta),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textoSuave, fontSize: 11, decoration: TextDecoration.lineThrough),
                            ),
                          ),
                        ],
                        const Spacer(),
                        _Estrellas(promedio: producto.promedioResenas),
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
      child: apagada ? null : const Center(child: Icon(Icons.diamond_outlined, size: 40, color: AppColors.textoSuave)),
    );
    final Widget foto = (url == null || url!.isEmpty)
        ? sinFoto
        : Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => sinFoto,
            loadingBuilder: (_, hijo, progreso) => progreso == null ? hijo : const ColoredBox(color: AppColors.superficie2),
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
          Text(formatoCalificacion(promedio), style: const TextStyle(color: AppColors.textoSuave, fontSize: 11)),
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
            color: const Color(0x8C281224),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x2EFFAAD7)),
          ),
          child: Icon(favorita ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 17, color: favorita ? const Color(0xFFF4A6C6) : Colors.white),
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.brush_rounded, size: 13, color: Color(0xFF9E2F63)),
          SizedBox(width: 4),
          Text(
            'Personalizable',
            style: TextStyle(color: Color(0xFF9E2F63), fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ],
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
