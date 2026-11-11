import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Botón con degradado rosa-lila y círculo con flecha, como en los bocetos.
class BotonPrimario extends StatelessWidget {
  const BotonPrimario({super.key, required this.texto, required this.onPressed, this.cargando = false});

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando;
    return Opacity(
      opacity: activo || cargando ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.degradado,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: AppColors.brillo.withValues(alpha: 0.5), blurRadius: 30, offset: Offset(0, 16), spreadRadius: -12)],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: activo ? onPressed : null,
            child: SizedBox(
              height: 58,
              child: Row(
                children: [
                  const SizedBox(width: 46),
                  Expanded(
                    child: Center(
                      child: cargando
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.sobreDegradado))
                          : Text(
                              texto,
                              style: TextStyle(color: AppColors.sobreDegradado, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(color: Color(0x40FFFFFF), shape: BoxShape.circle),
                    child: Icon(Icons.arrow_forward, size: 18, color: AppColors.sobreDegradado),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
