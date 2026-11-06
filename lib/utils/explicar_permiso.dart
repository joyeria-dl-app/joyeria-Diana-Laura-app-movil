import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// #276: antes del aviso de Android, la app explica para qué quiere mandar notificaciones. El permiso
// del sistema solo se pide si la persona elige Permitir.
Future<bool> explicarPermisoNotificaciones(
  GlobalKey<NavigatorState> navegador,
) async {
  // Al abrir la app con la sesión guardada, la pantalla aún no existe: se espera el primer cuadro.
  await WidgetsBinding.instance.endOfFrame;
  final contexto = navegador.currentState?.overlay?.context;
  if (contexto == null || !contexto.mounted) return false;
  final permitir = await showDialog<bool>(
    context: contexto,
    barrierDismissible: false,
    builder: (ctx) => const DialogoPermisoNotificaciones(),
  );
  return permitir ?? false;
}

class DialogoPermisoNotificaciones extends StatelessWidget {
  const DialogoPermisoNotificaciones({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.superficie,
    icon: Icon(Icons.notifications_active_rounded, color: AppColors.primario2),
    title: const Text('¿Te avisamos de tus pedidos?'),
    content: const Text(
      'Te mandamos una notificación cuando tu pedido cambie de estado: confirmado, en preparación, '
      'enviado o entregado. No usamos las notificaciones para publicidad y puedes apagarlas en Mi perfil.',
    ),
    actions: [
      TextButton(
        key: const Key('permiso_ahora_no'),
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Ahora no'),
      ),
      FilledButton(
        key: const Key('permiso_permitir'),
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Permitir'),
      ),
    ],
  );
}
