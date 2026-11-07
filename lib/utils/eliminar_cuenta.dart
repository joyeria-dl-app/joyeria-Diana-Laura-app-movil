import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/carrito_provider.dart';
import '../providers/favoritos_provider.dart';
import '../routes/app_routes.dart';
import '../services/perfil_service.dart';
import '../theme/app_theme.dart';

// #273 (ARCO, cancelación): la clienta elimina su cuenta desde Mi perfil. Se explica qué se borra y
// qué se conserva antes de confirmar; al terminar se cierra la sesión y se regresa al inicio.
Future<void> eliminarCuentaConConfirmacion(BuildContext context) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.superficie,
      title: const Text('¿Eliminar tu cuenta?'),
      content: const Text(
        'Se borran tus datos personales, tu carrito, tus favoritos y tus direcciones, y ya no podrás '
        'iniciar sesión con este correo. Tus compras se conservan sin tu nombre porque la tienda debe '
        'guardarlas. Esto no se puede deshacer.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          key: const Key('eliminar_cuenta_confirmar'),
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Eliminar mi cuenta'),
        ),
      ],
    ),
  );
  if (confirmar != true || !context.mounted) return;

  final navegador = Navigator.of(context);
  final avisos = ScaffoldMessenger.of(context);
  final perfil = context.read<PerfilService>();
  final auth = context.read<AuthProvider>();
  final carrito = context.read<CarritoProvider>();
  final favoritos = context.read<FavoritosProvider>();
  try {
    await auth.eliminarCuenta(perfil.eliminarCuenta);
  } on PerfilException catch (e) {
    // Por ejemplo, con pedidos o apartados en curso la tienda no deja eliminarla todavía.
    avisos.showSnackBar(SnackBar(content: Text(e.mensaje)));
    return;
  }
  carrito.limpiar();
  favoritos.limpiar();
  navegador.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  avisos.showSnackBar(const SnackBar(content: Text('Tu cuenta se eliminó')));
}
