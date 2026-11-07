import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/personalizacion.dart';
import '../routes/app_routes.dart';
import '../services/personalizacion_service.dart';
import '../theme/app_theme.dart';
import '../utils/fechas.dart';
import '../utils/formato.dart';
import '../widgets/decoracion.dart';
import '../widgets/estado_pedido.dart';
import 'detalle_screen.dart';

// HU-13 (#48): el cliente ve sus solicitudes de personalización y lo que respondió la tienda.
// Son las mismas que en "Mis personalizaciones" del sitio web.
class MisPersonalizacionesScreen extends StatefulWidget {
  const MisPersonalizacionesScreen({super.key});

  @override
  State<MisPersonalizacionesScreen> createState() => _MisPersonalizacionesScreenState();
}

class _MisPersonalizacionesScreenState extends State<MisPersonalizacionesScreen> {
  List<SolicitudPersonalizacion>? _solicitudes;
  PersonalizacionException? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final solicitudes = await context.read<PersonalizacionService>().misSolicitudes();
      if (mounted) setState(() => _solicitudes = solicitudes);
    } on PersonalizacionException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _verPieza(SolicitudPersonalizacion s) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DetalleScreen(productoId: s.productoId))).then((_) => _cargar());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          const Destellos(),
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
                const Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, 0), child: TituloDegradado('Mis personalizaciones', tamano: 28)),
                Expanded(child: _contenido()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_error != null) {
      return _error!.sinSesion
          ? AvisoVacio(
              icono: Icons.lock_outline_rounded,
              titulo: 'Inicia sesión para ver tus personalizaciones',
              texto: 'Con tu cuenta ves aquí las mismas solicitudes que en el sitio web.',
              boton: 'Iniciar sesión',
              iconoBoton: Icons.login_rounded,
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
            )
          : AvisoVacio(
              icono: Icons.wifi_off_rounded,
              titulo: 'Sin conexión',
              texto: _error!.mensaje,
              boton: 'Reintentar',
              iconoBoton: Icons.refresh_rounded,
              onPressed: _cargar,
            );
    }
    final solicitudes = _solicitudes;
    if (solicitudes == null) return Center(child: CircularProgressIndicator(color: AppColors.primario));
    if (solicitudes.isEmpty) {
      return AvisoVacio(
        icono: Icons.brush_rounded,
        titulo: 'Aún no pides personalizaciones',
        texto: 'En el detalle de las piezas que dicen "Personalizable" puedes pedir un grabado o un cambio de diseño.',
        boton: 'Ver catálogo',
        iconoBoton: Icons.diamond_rounded,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.catalogo),
      );
    }
    final enRevision = solicitudes.where((s) => s.estado == EstadoSolicitud.pendiente).length;
    return RefreshIndicator(
      color: AppColors.primario,
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Text(
            enRevision == 0
                ? '${solicitudes.length} ${solicitudes.length == 1 ? 'solicitud' : 'solicitudes'}'
                : '${solicitudes.length} ${solicitudes.length == 1 ? 'solicitud' : 'solicitudes'} · $enRevision en revisión',
            style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          for (final s in solicitudes) ...[_TarjetaSolicitud(solicitud: s, onVerPieza: () => _verPieza(s)), const SizedBox(height: 12)],
        ],
      ),
    );
  }
}

class _TarjetaSolicitud extends StatelessWidget {
  const _TarjetaSolicitud({required this.solicitud, required this.onVerPieza});
  final SolicitudPersonalizacion solicitud;
  final VoidCallback onVerPieza;

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final chip = switch (s.estado) {
      EstadoSolicitud.pendiente => const ChipEstado('En revisión', tono: TonoEstado.aviso, icono: Icons.schedule_rounded),
      EstadoSolicitud.aprobada when s.utilizada => const ChipEstado('Comprada', tono: TonoEstado.exito, icono: Icons.shopping_bag_outlined),
      EstadoSolicitud.aprobada => const ChipEstado('Aprobada', tono: TonoEstado.exito, icono: Icons.check_rounded),
      EstadoSolicitud.rechazada => const ChipEstado('No aprobada', tono: TonoEstado.error, icono: Icons.close_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FotoPieza(url: s.productoImagen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.productoNombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (s.fechaCreacion case final f?) 'Pedida el ${fechaCorta(f)}',
                        if (s.precioPersonalizacion case final p? when p > 0) '+${formatoPrecio(p)}',
                      ].join(' · '),
                      style: TextStyle(color: AppColors.textoSuave, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              chip,
            ],
          ),
          const SizedBox(height: 12),
          Text(s.detalle, style: const TextStyle(fontSize: 13, height: 1.45)),
          if (s.imagenReferencia case final url?) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: 'Foto de referencia',
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _Respuesta(solicitud: s, onVerPieza: onVerPieza),
        ],
      ),
    );
  }
}

// Lo que dijo la tienda y qué puede hacer el cliente.
class _Respuesta extends StatelessWidget {
  const _Respuesta({required this.solicitud, required this.onVerPieza});
  final SolicitudPersonalizacion solicitud;
  final VoidCallback onVerPieza;

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final respondida = s.fechaRespuesta == null ? '' : ' el ${fechaCorta(s.fechaRespuesta!)}';
    final (icono, color, fondo, texto) = switch (s.estado) {
      EstadoSolicitud.pendiente => (
        Icons.hourglass_top_rounded,
        colorAviso,
        const Color(0x1AF6A723),
        'La tienda está revisando tu solicitud. Te avisaremos por correo.',
      ),
      EstadoSolicitud.aprobada when s.utilizada => (
        Icons.check_circle_outline_rounded,
        AppColors.exito,
        const Color(0x1A2EBD85),
        'Ya compraste esta pieza con tu personalización.',
      ),
      EstadoSolicitud.aprobada => (
        Icons.check_circle_outline_rounded,
        AppColors.exito,
        const Color(0x1A2EBD85),
        'La tienda aprobó tu personalización$respondida. Ya puedes comprar la pieza.',
      ),
      EstadoSolicitud.rechazada => (
        Icons.info_outline_rounded,
        AppColors.error,
        const Color(0x1AEF4B5B),
        (s.motivoRechazo?.trim().isNotEmpty ?? false)
            ? 'Motivo$respondida: ${s.motivoRechazo!.trim()}'
            : 'La tienda no pudo aprobar esta personalización$respondida.',
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 12, height: 1.4))),
          if (s.lista || s.estado == EstadoSolicitud.rechazada) TextButton(onPressed: onVerPieza, child: Text(s.lista ? 'Ver pieza' : 'Intentar otra')),
        ],
      ),
    );
  }
}
