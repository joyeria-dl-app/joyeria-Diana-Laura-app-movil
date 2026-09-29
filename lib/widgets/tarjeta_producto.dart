import 'package:flutter/material.dart';

import '../models/producto.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';

// Tarjeta del catálogo (.pcard de los bocetos): foto, nombre y precio.
class TarjetaProducto extends StatelessWidget {
  const TarjetaProducto({super.key, required this.producto, this.onTap});

  final Producto producto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
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
                  _Foto(url: producto.imagen),
                  // Oscurece la parte baja de la foto para que se lea el texto.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.superficie],
                      ),
                    ),
                  ),
                  if (producto.esNuevo && !producto.agotado)
                    const Positioned(top: 10, left: 10, child: _Insignia('Nuevo', color: AppColors.primario)),
                  if (producto.agotado) const Center(child: _Insignia('Agotado')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.texto, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatoPrecio(producto.precioFinal),
                        style: const TextStyle(color: AppColors.primario, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      if (producto.tieneDescuento) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            formatoPrecio(producto.precioVenta),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textoSuave,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Foto extends StatelessWidget {
  const _Foto({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const sinFoto = ColoredBox(
      color: AppColors.superficie2,
      child: Center(child: Icon(Icons.diamond_outlined, size: 40, color: AppColors.textoSuave)),
    );
    if (url == null || url!.isEmpty) return sinFoto;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => sinFoto,
      loadingBuilder: (_, hijo, progreso) => progreso == null ? hijo : const ColoredBox(color: AppColors.superficie2),
    );
  }
}

// Fondo oscuro para que se lea sobre cualquier foto.
class _Insignia extends StatelessWidget {
  const _Insignia(this.texto, {this.color = AppColors.texto});
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
