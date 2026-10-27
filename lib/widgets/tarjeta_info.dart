import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Tarjeta informativa de los bocetos: ícono en un cuadro de 44 px, título y una línea de texto
// (por ejemplo "Código de entrega" en Seguimiento). Es el mismo diseño que _Tarjeta de
// seguimiento_screen.dart; aquí queda compartida para Zonas de entrega (HU-16, #59).
class TarjetaInfo extends StatelessWidget {
  const TarjetaInfo({super.key, required this.icono, required this.titulo, this.texto = ''});

  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(14)),
            child: Icon(icono, size: 21, color: AppColors.primario),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (texto.isNotEmpty) Text(texto, style: TextStyle(color: AppColors.textoSuave, fontSize: 11.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
