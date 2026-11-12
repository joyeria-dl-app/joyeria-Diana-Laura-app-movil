import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

// Debajo de "Iniciar sesión" en las pantallas que piden cuenta (#322): quien todavía no tiene
// cuenta va directo al registro, sin pasar por el inicio de sesión.
class InvitacionCrearCuenta extends StatelessWidget {
  const InvitacionCrearCuenta({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('¿No tienes cuenta?', style: TextStyle(color: AppColors.textoSuave, fontSize: 13)),
          TextButton(
            key: const Key('invitacion_crear_cuenta'),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
            style: TextButton.styleFrom(foregroundColor: AppColors.primario, minimumSize: const Size(48, 48)),
            child: const Text('Crear cuenta', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
