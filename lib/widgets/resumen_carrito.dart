import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formato.dart';

// Tarjeta con subtotal, envío y total del carrito (boceto 6a, P9).
class ResumenCarrito extends StatelessWidget {
  const ResumenCarrito({super.key, required this.subtotal, required this.total});

  final double subtotal;
  final double total;

  @override
  Widget build(BuildContext context) {
    const suave = TextStyle(color: AppColors.textoSuave, fontSize: 13);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        children: [
          _Renglon(
            izquierda: const Text('Subtotal', style: suave),
            derecha: Text(formatoPrecioCompleto(subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 8),
          // El envío depende de la dirección y se calcula al pagar (HU-12).
          const _Renglon(
            izquierda: Text('Envío', style: suave),
            derecha: Text(
              'Se calcula al pagar',
              style: TextStyle(color: AppColors.textoSuave, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: _LineaPunteada()),
          _Renglon(
            izquierda: const Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            derecha: Text(
              formatoPrecioCompleto(total),
              style: const TextStyle(color: AppColors.primario, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// Barra inferior de vidrio con el total y el botón "Ir a pagar" (boceto 6a, P9).
class BarraPagar extends StatelessWidget {
  const BarraPagar({super.key, required this.total, required this.onPagar});

  final double total;
  final VoidCallback? onPagar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        padding: const EdgeInsets.fromLTRB(22, 8, 8, 8),
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
                  const Text(
                    'Total',
                    style: TextStyle(color: AppColors.textoSuave, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  Text(formatoPrecio(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                ],
              ),
            ),
            Opacity(
              opacity: onPagar == null ? 0.5 : 1,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.degradado, borderRadius: BorderRadius.circular(22)),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: onPagar,
                    child: const SizedBox(
                      height: 54,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ir a pagar',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon({required this.izquierda, required this.derecha});
  final Widget izquierda;
  final Widget derecha;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [izquierda, derecha]);
}

// border-top: 1.5px dashed del boceto.
class _LineaPunteada extends StatelessWidget {
  const _LineaPunteada();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final guiones = (limites.maxWidth / 7).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(guiones, (_) => const SizedBox(width: 4, height: 1.5, child: ColoredBox(color: AppColors.borde))),
        );
      },
    );
  }
}
