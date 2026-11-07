import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pedido.dart';
import '../routes/app_routes.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../widgets/decoracion.dart';
import '../widgets/estado_pedido.dart';
import 'seguimiento_screen.dart';

// Se abre al tocar el aviso de un pedido (HU-15, #56): el aviso solo trae el número del pedido,
// así que se consultan los pedidos de la cuenta y se muestra el seguimiento de ese.
class AbrirPedidoScreen extends StatefulWidget {
  const AbrirPedidoScreen({super.key, required this.pedidoId});
  final int pedidoId;

  @override
  State<AbrirPedidoScreen> createState() => _AbrirPedidoScreenState();
}

class _AbrirPedidoScreenState extends State<AbrirPedidoScreen> {
  late Future<Pedido?> _pedido = _buscar();

  Future<Pedido?> _buscar() async {
    final pedidos = await context.read<PedidoService>().misPedidos();
    for (final p in pedidos) {
      if (p.id == widget.pedidoId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Pedido?>(
      future: _pedido,
      builder: (context, estado) {
        final pedido = estado.data;
        if (estado.connectionState == ConnectionState.done && pedido != null) return SeguimientoScreen(pedido: pedido);
        return Scaffold(
          body: Stack(
            children: [
              const FondoResplandor(),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: BotonCristal(icono: Icons.arrow_back_rounded, descripcion: 'Regresar', onPressed: () => Navigator.maybePop(context)),
                    ),
                    Expanded(child: _estado(estado)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _estado(AsyncSnapshot<Pedido?> estado) {
    if (estado.connectionState != ConnectionState.done) return Center(child: CircularProgressIndicator(color: AppColors.primario));
    final error = estado.error;
    if (error is PedidoException && error.sinSesion) {
      return AvisoVacio(
        icono: Icons.lock_outline_rounded,
        titulo: 'Inicia sesión para ver tu pedido',
        texto: 'El aviso es de un pedido de tu cuenta. Entra para ver cómo va.',
        boton: 'Iniciar sesión',
        iconoBoton: Icons.login_rounded,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
      );
    }
    if (error != null) {
      return AvisoVacio(
        icono: Icons.wifi_off_rounded,
        titulo: 'Sin conexión',
        texto: 'No se pudo abrir tu pedido. Revisa tu conexión e intenta de nuevo.',
        boton: 'Reintentar',
        iconoBoton: Icons.refresh_rounded,
        onPressed: () {
          final nuevo = _buscar();
          setState(() {
            _pedido = nuevo;
          });
        },
      );
    }
    // El pedido no es de la cuenta con la que se inició sesión en este teléfono.
    return AvisoVacio(
      icono: Icons.receipt_long_rounded,
      titulo: 'No encontramos ese pedido',
      texto: 'Revisa Mis pedidos para ver los pedidos de tu cuenta.',
      boton: 'Ver mis pedidos',
      iconoBoton: Icons.receipt_long_rounded,
      onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.misPedidos),
    );
  }
}
