import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/fotos.dart';

// Foto de una pieza descargada de internet (#234): pide a Cloudinary la versión reducida, la
// decodifica al tamaño en que se muestra para usar menos memoria y la guarda en el teléfono para no
// descargarla otra vez al volver a abrir la app.
class FotoRed extends StatelessWidget {
  const FotoRed(
    this.url, {
    super.key,
    this.ancho = anchoFotoChica,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.error,
    this.cargando,
    this.semanticLabel,
  });

  final String url;
  // Ancho de la foto que se pide a Cloudinary y al que se decodifica.
  final int ancho;
  final BoxFit fit;
  final double? width;
  final double? height;
  // Lo que se ve si la foto no se pudo descargar.
  final Widget? error;
  // Lo que se ve mientras descarga.
  final Widget? cargando;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final foto = CachedNetworkImage(
      imageUrl: fotoReducida(url, ancho: ancho),
      memCacheWidth: ancho,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: cargando == null ? null : (_, _) => cargando!,
      errorWidget: (_, _, _) => error ?? const SizedBox.shrink(),
    );
    return semanticLabel == null ? foto : Semantics(label: semanticLabel, image: true, child: foto);
  }
}
