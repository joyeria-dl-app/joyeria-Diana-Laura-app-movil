import 'package:flutter/material.dart';

import '../services/dispositivo_root.dart';
import '../theme/app_theme.dart';

// Franja fija arriba de todas las pantallas cuando el teléfono tiene root (#99).
class AvisoRoot extends StatelessWidget {
  const AvisoRoot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          key: const Key('aviso_root'),
          color: AppColors.error,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.gpp_maybe_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      avisoRoot,
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // La franja ya ocupa la barra de estado: la pantalla de abajo no vuelve a dejar ese espacio.
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: true, child: child),
        ),
      ],
    );
  }
}
