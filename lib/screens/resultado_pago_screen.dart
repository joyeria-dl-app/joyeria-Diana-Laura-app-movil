import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/decoracion.dart';
import '../widgets/estado_pedido.dart';

// HU-12: lo que pasó con el pago de Mercado Pago al regresar a la app.
// Devuelve true si el cliente quiere intentar el pago de nuevo.
class ResultadoPagoScreen extends StatelessWidget {
  const ResultadoPagoScreen({super.key, required this.resultado, required this.folio, required this.monto, this.apartado = false});

  final ResultadoPago resultado;
  final String folio;
  final double monto;
  final bool apartado;

  @override
  Widget build(BuildContext context) {
    final (icono, color, titulo, texto, etiqueta) = switch (resultado) {
      ResultadoPago.aprobado => (
        Icons.check_rounded,
        AppColors.primario,
        '¡Pago recibido!',
        apartado ? 'Tu pago inicial quedó registrado y tus piezas siguen apartadas.' : 'Tu pedido quedó pagado. Te avisaremos cuando esté listo.',
        'Pagado',
      ),
      ResultadoPago.pendiente => (
        Icons.schedule_rounded,
        const Color(0xFFF6A723),
        'Tu pago está en proceso',
        'Mercado Pago lo está revisando (por ejemplo, si pagaste en OXXO). Se actualiza solo cuando lo confirme.',
        'En proceso',
      ),
      ResultadoPago.rechazado => (
        Icons.close_rounded,
        const Color(0xFFE5677A),
        'El pago no se completó',
        'No se hizo ningún cargo. Puedes intentarlo de nuevo con otra tarjeta o método.',
        'Sin pagar',
      ),
    };
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          const Destellos(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    child: Icon(icono, size: 44, color: color),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.superficie,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.borde),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${apartado ? 'Apartado' : 'Pedido'} $folio', style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text(
                              etiqueta,
                              style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(apartado ? 'Pago inicial' : 'Total', style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                          Text(formatoPrecioCompleto(monto), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Método', style: TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                          Text('Mercado Pago', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (resultado == ResultadoPago.rechazado) ...[
                  BotonDegradado(texto: 'Intentar de nuevo', icono: Icons.refresh_rounded, ancho: true, onPressed: () => Navigator.pop(context, true)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ahora no')),
                ] else
                  BotonDegradado(
                    texto: apartado ? 'Ver mis apartados' : 'Ver mi pedido',
                    icono: apartado ? Icons.bookmark_border_rounded : Icons.receipt_long_outlined,
                    ancho: true,
                    onPressed: () => Navigator.pop(context, false),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
