import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../utils/fechas.dart';

// Color de "Pendiente" en los bocetos (--warn).
const colorAviso = Color(0xFFF6A723);

// Nombre de cada estado del pedido como lo ve el cliente.
String nombreEstado(String estado) => switch (estado) {
  'pendiente' => 'Pendiente',
  'confirmado' => 'Confirmado',
  'en_preparacion' => 'En preparación',
  'enviado' => 'Enviado',
  'entregado' => 'Entregado',
  'cancelado' => 'Cancelado',
  'expirado' => 'Expirado',
  _ => estado,
};

// Chip de estado (.tag de los bocetos).
class ChipEstado extends StatelessWidget {
  const ChipEstado(this.texto, {super.key, this.tono = TonoEstado.rosa, this.icono});

  factory ChipEstado.pedido(String estado, {Key? key}) => ChipEstado(
    nombreEstado(estado),
    key: key,
    tono: switch (estado) {
      'pendiente' => TonoEstado.aviso,
      'entregado' => TonoEstado.exito,
      'cancelado' || 'expirado' => TonoEstado.error,
      _ => TonoEstado.rosa,
    },
  );

  final String texto;
  final TonoEstado tono;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final (fondo, color) = switch (tono) {
      TonoEstado.aviso => (const Color(0x26F6A723), colorAviso),
      TonoEstado.exito => (const Color(0x262EBD85), AppColors.exito),
      TonoEstado.error => (const Color(0x26EF4B5B), AppColors.error),
      TonoEstado.rosa => (AppColors.suave, AppColors.primario),
      TonoEstado.claro => (const Color(0x40FFFFFF), Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[Icon(icono, size: 13, color: color), const SizedBox(width: 4)],
          Text(
            texto,
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

enum TonoEstado { rosa, aviso, exito, error, claro }

// Un paso de la línea de tiempo del pedido.
class PasoPedido {
  const PasoPedido({required this.titulo, required this.icono, required this.fecha, required this.hecho, required this.actual});
  final String titulo;
  final IconData icono;
  final DateTime? fecha;
  final bool hecho;
  final bool actual;
}

// Pasos según el tipo de entrega, con la fecha de cada cambio de estado (historial del backend).
List<PasoPedido> pasosDe(Pedido p) {
  final orden = <(String, String, IconData)>[
    ('pendiente', 'Pedido recibido', Icons.receipt_long_outlined),
    ('confirmado', 'Confirmado', Icons.check_rounded),
    ('en_preparacion', 'En preparación', Icons.inventory_2_outlined),
    if (p.domicilio) ('enviado', 'Enviado', Icons.local_shipping_outlined),
    ('entregado', p.domicilio ? 'Entregado' : 'Recogido en tienda', p.domicilio ? Icons.home_outlined : Icons.storefront_outlined),
  ];
  if (p.cancelado) {
    // Hasta donde llegó el pedido y luego la cancelación.
    final pasos = <PasoPedido>[
      for (final (estado, titulo, icono) in orden)
        if (p.fechaDe(estado) != null) PasoPedido(titulo: titulo, icono: icono, fecha: p.fechaDe(estado), hecho: true, actual: false),
    ];
    return [...pasos, PasoPedido(titulo: nombreEstado(p.estado), icono: Icons.close_rounded, fecha: p.fechaDe(p.estado), hecho: true, actual: true)];
  }
  // Un pedido a domicilio que se entregó sin pasar por "enviado" no deja huecos: el índice manda.
  final actual = orden.indexWhere((o) => o.$1 == p.estado);
  return [
    for (var i = 0; i < orden.length; i++)
      PasoPedido(
        titulo: orden[i].$2,
        icono: orden[i].$3,
        fecha: i <= actual ? p.fechaDe(orden[i].$1) : null,
        hecho: i < actual || (i == actual && p.entregado),
        actual: i == actual && !p.entregado,
      ),
  ];
}

// Línea de tiempo vertical (.tl de los bocetos 9a y 9c–9e).
class LineaTiempo extends StatelessWidget {
  const LineaTiempo({super.key, required this.pasos, this.error = false});
  final List<PasoPedido> pasos;
  // Pedido cancelado: el último paso va en rojo.
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < pasos.length; i++)
          _Paso(
            paso: pasos[i],
            ultimo: i == pasos.length - 1,
            siguienteHecho: i < pasos.length - 1 && (pasos[i + 1].hecho || pasos[i + 1].actual),
            error: error && i == pasos.length - 1,
          ),
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.paso, required this.ultimo, required this.siguienteHecho, required this.error});
  final PasoPedido paso;
  final bool ultimo;
  final bool siguienteHecho;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final activo = paso.hecho || paso.actual;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                _Punto(paso: paso, error: error),
                if (!ultimo) Expanded(child: Container(width: 2, color: siguienteHecho ? AppColors.primario : AppColors.superficie2)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: ultimo ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paso.titulo,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                      color: error ? AppColors.error : (paso.actual ? AppColors.primario : (activo ? AppColors.texto : AppColors.textoSuave)),
                    ),
                  ),
                  if (paso.fecha != null) Text(fechaHora(paso.fecha!), style: const TextStyle(color: AppColors.textoSuave, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.paso, required this.error});
  final PasoPedido paso;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (error) {
      return Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
        child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
      );
    }
    if (paso.actual) {
      return Container(
        width: 30,
        height: 30,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primario, width: 2),
          boxShadow: const [BoxShadow(color: AppColors.suave, spreadRadius: 4)],
        ),
        child: const DecoratedBox(
          decoration: BoxDecoration(color: AppColors.primario, shape: BoxShape.circle),
        ),
      );
    }
    if (paso.hecho) {
      return Container(
        width: 26,
        height: 26,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primario, AppColors.primario2]),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 15, color: Colors.white),
      );
    }
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(color: AppColors.superficie2, shape: BoxShape.circle),
      child: Icon(paso.icono, size: 14, color: AppColors.textoSuave),
    );
  }
}

// Cuadro vacío con ícono, título, texto y botón (9b y 10b, como 6c del carrito).
class AvisoVacio extends StatelessWidget {
  const AvisoVacio({super.key, required this.icono, required this.titulo, required this.texto, this.boton, this.iconoBoton, this.onPressed});
  final IconData icono;
  final String titulo;
  final String texto;
  final String? boton;
  final IconData? iconoBoton;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(30)),
              child: Icon(icono, size: 40, color: AppColors.primario),
            ),
            const SizedBox(height: 18),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
              ),
            ),
            if (boton != null) ...[const SizedBox(height: 22), BotonDegradado(texto: boton!, icono: iconoBoton, onPressed: onPressed)],
          ],
        ),
      ),
    );
  }
}

// Botón con degradado rosa-lila de los avisos y de "Abonar por WhatsApp".
class BotonDegradado extends StatelessWidget {
  const BotonDegradado({super.key, required this.texto, this.icono, this.onPressed, this.ancho = false});
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final bool ancho;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
            constraints: BoxConstraints(minWidth: ancho ? double.infinity : 210),
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icono != null) ...[Icon(icono, size: 20, color: Colors.white), const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Miniatura de una pieza con el diamante cuando no hay foto.
class FotoPieza extends StatelessWidget {
  const FotoPieza({super.key, required this.url, this.tamano = 52, this.radio = 16});
  final String? url;
  final double tamano;
  final double radio;

  @override
  Widget build(BuildContext context) {
    const sinFoto = ColoredBox(
      color: AppColors.superficie2,
      child: Center(child: Icon(Icons.diamond_outlined, size: 20, color: AppColors.textoSuave)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: SizedBox(
        width: tamano,
        height: tamano,
        child: url == null ? sinFoto : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => sinFoto),
      ),
    );
  }
}
