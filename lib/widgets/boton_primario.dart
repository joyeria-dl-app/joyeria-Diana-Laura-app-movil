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
          boxShadow: const [BoxShadow(color: Color(0x80CF819F), blurRadius: 30, offset: Offset(0, 16), spreadRadius: -12)],
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
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(texto, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(color: Color(0x40FFFFFF), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
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
