import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Pasos Carrito → Entrega y pago → Listo (.stepper de los bocetos 8a–8f).
class PasosPedido extends StatelessWidget {
  const PasosPedido({super.key, required this.actual});

  // 2 mientras se confirma; 3 cuando ya quedó listo.
  final int actual;

  static const _nombres = ['Carrito', 'Entrega y pago', 'Listo'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 1; i <= 3; i++) ...[
              _Circulo(numero: i, hecho: i < actual || actual == 3, actual: i == actual && actual != 3),
              if (i < 3)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: i < actual ? null : AppColors.superficie2,
                      gradient: i < actual ? const LinearGradient(colors: [AppColors.primario, AppColors.primario2]) : null,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i <= 3; i++)
              Text(
                _nombres[i - 1],
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: i == actual ? AppColors.primario : AppColors.textoSuave),
              ),
          ],
        ),
      ],
    );
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo({required this.numero, required this.hecho, required this.actual});
  final int numero;
  final bool hecho;
  final bool actual;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hecho ? null : (actual ? AppColors.suave : AppColors.superficie2),
        gradient: hecho ? const LinearGradient(colors: [AppColors.primario, AppColors.primario2]) : null,
        border: actual ? Border.all(color: AppColors.primario, width: 2) : null,
      ),
      child: hecho
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : Text(
              '$numero',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: actual ? AppColors.primario : AppColors.textoSuave),
            ),
    );
  }
}
