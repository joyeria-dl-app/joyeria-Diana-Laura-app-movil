import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pedido.dart';
import '../routes/app_routes.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../utils/fechas.dart';
import '../utils/formato.dart';
import '../widgets/decoracion.dart';
import '../widgets/estado_pedido.dart';

// Detalle de un apartado con su historial de abonos (HU-14, #51), como la tabla de abonos
// de Mis apartados del sitio web: fecha, monto, método y si la tienda ya lo confirmó.
class DetalleApartadoScreen extends StatefulWidget {
  const DetalleApartadoScreen({super.key, required this.apartado});

  // Lo que ya se mostró en Mis apartados; el detalle completo se pide al abrir.
  final Apartado apartado;

  @override
  State<DetalleApartadoScreen> createState() => _DetalleApartadoScreenState();
}

class _DetalleApartadoScreenState extends State<DetalleApartadoScreen> {
  late Future<Apartado> _detalle = _cargar();

  Future<Apartado> _cargar() => context.read<PedidoService>().detalleApartado(widget.apartado.id);

  void _recargar() {
    final nuevo = _cargar();
    setState(() {
      _detalle = nuevo;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [BotonCristal(icono: Icons.arrow_back_rounded, descripcion: 'Regresar', onPressed: () => Navigator.maybePop(context))],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Antetitulo(widget.apartado.folio), const SizedBox(height: 2), const TituloDegradado('Mi apartado', tamano: 28)],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<Apartado>(
                    future: _detalle,
                    builder: (context, estado) {
                      if (estado.connectionState != ConnectionState.done) {
                        return Center(child: CircularProgressIndicator(color: AppColors.primario));
                      }
                      final error = estado.error;
                      if (error is PedidoException && error.sinSesion) {
                        return AvisoVacio(
                          icono: Icons.lock_outline_rounded,
                          titulo: 'Inicia sesión para ver tu apartado',
                          texto: 'Con tu cuenta ves tus piezas y cada abono que has hecho.',
                          boton: 'Iniciar sesión',
                          iconoBoton: Icons.login_rounded,
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                        );
                      }
                      if (error != null) {
                        return AvisoVacio(
                          icono: Icons.wifi_off_rounded,
                          titulo: 'Sin conexión',
                          texto: 'No se pudo cargar tu apartado. Revisa tu conexión e intenta de nuevo.',
                          boton: 'Reintentar',
                          iconoBoton: Icons.refresh_rounded,
                          onPressed: _recargar,
                        );
                      }
                      return _Contenido(apartado: estado.data!);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.apartado});
  final Apartado apartado;

  @override
  Widget build(BuildContext context) {
    final a = apartado;
    final cancelado = a.estado == 'cancelado';
    // Del más reciente al más antiguo, como se consulta un historial.
    final abonos = [...a.abonos]..sort((x, y) => (y.fecha ?? DateTime(0)).compareTo(x.fecha ?? DateTime(0)));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final pieza in a.piezas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      FotoPieza(url: pieza.imagen, tamano: 48, radio: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pieza.cantidad > 1 ? '${pieza.nombre} × ${pieza.cantidad}' : pieza.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(formatoPrecioCompleto(pieza.precioUnitario * pieza.cantidad), style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatoPrecioCompleto(a.montoPagado)} de ${formatoPrecioCompleto(a.montoTotal)}',
                      style: TextStyle(color: AppColors.textoSuave, fontSize: 12),
                    ),
                  ),
                  // Un apartado cancelado ya no tiene saldo por pagar.
                  if (cancelado)
                    const ChipEstado('Cancelado', tono: TonoEstado.error)
                  else
                    Text(
                      a.saldo <= 0.009 ? 'Liquidado' : 'Faltan ${formatoPrecioCompleto(a.saldo)}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: a.avance, minHeight: 7, backgroundColor: AppColors.superficie2, color: AppColors.primario),
              ),
              if (!cancelado && (a.fechaLimite != null || a.plan != null)) ...[
                const SizedBox(height: 8),
                Text(
                  [if (a.fechaLimite != null) 'Liquidar antes del ${fechaCorta(a.fechaLimite!)}', ?a.plan].join(' · '),
                  style: TextStyle(color: AppColors.textoSuave, fontSize: 11.5),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(abonos.isEmpty ? 'Abonos' : 'Abonos · ${abonos.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (abonos.isEmpty)
          _Tarjeta(
            child: Text('Todavía no hay abonos registrados en este apartado.', style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5)),
          )
        else
          _Tarjeta(
            child: Column(
              children: [
                for (final (i, abono) in abonos.indexed) ...[
                  if (i > 0) Divider(color: AppColors.borde, height: 20),
                  _RenglonAbono(abono: abono, apartadoCancelado: cancelado),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RenglonAbono extends StatelessWidget {
  const _RenglonAbono({required this.abono, required this.apartadoCancelado});
  final Abono abono;
  // Si el apartado se canceló, un abono que nunca se confirmó ya no está "por confirmar".
  final bool apartadoCancelado;

  (String, TonoEstado) get _estado => switch (abono.estado) {
    'pagado' => ('Confirmado', TonoEstado.exito),
    'rechazado' => ('No aceptado', TonoEstado.error),
    _ when apartadoCancelado => ('No se confirmó', TonoEstado.error),
    _ => ('Por confirmar', TonoEstado.aviso),
  };

  @override
  Widget build(BuildContext context) {
    final (texto, tono) = _estado;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(14)),
          child: Icon(Icons.payments_outlined, size: 20, color: AppColors.primario),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatoPrecioCompleto(abono.monto), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                [if (abono.fecha != null) fechaCorta(abono.fecha!), ?abono.metodo].join(' · '),
                style: TextStyle(color: AppColors.textoSuave, fontSize: 11.5),
              ),
            ],
          ),
        ),
        ChipEstado(texto, tono: tono),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.superficie,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.borde),
    ),
    child: child,
  );
}
