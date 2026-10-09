import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pedido.dart';
import '../services/pedido_service.dart';

// Abre el enlace de pago en el navegador del teléfono. Las pruebas lo cambian para no abrir nada.
Future<bool> Function(Uri) abrirEnlacePago = (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

// HU-12: pide la preferencia y abre la página de pago de Mercado Pago. Al terminar, Mercado
// Pago regresa a la app con joyeriadl://pago (ver el backend, utils/pagoApp.ts).
// Devuelve true si se abrió la página.
Future<bool> abrirPagoMercadoPago(BuildContext context, Future<PreferenciaPago> Function() pedirPreferencia) async {
  final mensajero = ScaffoldMessenger.of(context);
  try {
    final preferencia = await pedirPreferencia();
    if (!await abrirEnlacePago(Uri.parse(preferencia.enlace))) throw const PedidoException('No se pudo abrir Mercado Pago.');
    return true;
  } on PedidoException catch (e) {
    mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.mensaje)));
    return false;
  }
}
