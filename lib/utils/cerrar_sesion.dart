import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/carrito_provider.dart';
import '../providers/favoritos_provider.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

// HU-14 (#52): pregunta antes de cerrar la sesión, como el sitio web. Al confirmar se borra la
// sesión del teléfono, se olvidan el carrito y los favoritos de la cuenta y se regresa al inicio
// sin poder volver atrás a pantallas de la cuenta.
Future<void> cerrarSesionConConfirmacion(BuildContext context) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.superficie,
      title: const Text('¿Cerrar sesión?'),
      content: const Text('Tu carrito y tus favoritos se quedan guardados en tu cuenta para la próxima vez.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );
  if (confirmar != true || !context.mounted) return;

  final navegador = Navigator.of(context);
  final carrito = context.read<CarritoProvider>();
  final favoritos = context.read<FavoritosProvider>();
  await context.read<AuthProvider>().cerrarSesion();
  carrito.limpiar();
  favoritos.limpiar();
  navegador.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
}
