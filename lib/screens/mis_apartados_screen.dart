import 'dart:math' as math;

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
import 'seguimiento_screen.dart';

// Mis apartados (boceto P12, estados 10a y 10b de Bocetos_Sprint3).
class MisApartadosScreen extends StatefulWidget {
  const MisApartadosScreen({super.key});

  @override
  State<MisApartadosScreen> createState() => _MisApartadosScreenState();
}

class _MisApartadosScreenState extends State<MisApartadosScreen> {
  List<Apartado>? _apartados;
  PedidoException? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final apartados = await context.read<PedidoService>().misApartados();
      if (mounted) {
        setState(() {
          _apartados = apartados;
          _error = null;
        });
      }
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  List<Apartado> get _activos => (_apartados ?? const <Apartado>[]).where((a) => a.activo).toList();

  void _ayuda() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.fondo,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 22, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Cómo funciona un apartado?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 10),
              Text(
                'Pagas al menos el 50% para reservar tus piezas y el resto en abonos antes de la fecha límite. '
                'Cuando liquidas, las recoges en la tienda. Los abonos se registran en tienda o por WhatsApp.',
                style: TextStyle(color: AppColors.textoSuave, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hayActivos = _activos.isNotEmpty;
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
                    children: [
                      BotonCristal(icono: Icons.arrow_back_rounded, descripcion: 'Regresar', onPressed: () => Navigator.maybePop(context)),
                      const Spacer(),
                      BotonCristal(icono: Icons.help_outline_rounded, descripcion: 'Cómo funciona', onPressed: _ayuda),
                    ],
                  ),
                ),
                const Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, 0), child: TituloDegradado('Mis apartados', tamano: 28)),
                Expanded(child: _contenido()),
                if (hayActivos)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: BotonDegradado(
                      texto: 'Abonar por WhatsApp',
                      icono: Icons.chat_outlined,
                      ancho: true,
                      onPressed: () => abrirWhatsApp(context, 'Hola, quiero abonar a mi apartado ${_activos.map((a) => a.folio).join(', ')}.'),
                    ),
                  ),
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
              titulo: 'Inicia sesión para ver tus apartados',
              texto: 'Con tu cuenta ves aquí los mismos apartados que en el sitio web.',
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
    final apartados = _apartados;
    if (apartados == null) return const Center(child: CircularProgressIndicator(color: AppColors.primario));
    if (apartados.isEmpty) {
      // 10b.
      return AvisoVacio(
        icono: Icons.bookmark_border_rounded,
        titulo: 'No tienes apartados',
        texto: 'Aparta una pieza desde tu carrito con el 50% y págala en partes.',
        boton: 'Ir al carrito',
        iconoBoton: Icons.shopping_bag_outlined,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.carrito),
      );
    }
    final activos = _activos;
    final total = activos.fold<double>(0, (s, a) => s + a.montoTotal);
    final pagado = activos.fold<double>(0, (s, a) => s + a.montoPagado);
    final falta = activos.fold<double>(0, (s, a) => s + a.saldo);
    return RefreshIndicator(
      color: AppColors.primario,
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        children: [
          if (activos.isNotEmpty) ...[
            _Resumen(avance: total <= 0 ? 0 : (pagado / total).clamp(0, 1).toDouble(), falta: falta, activos: activos.length),
            const SizedBox(height: 14),
          ],
          for (final a in apartados) ...[_TarjetaApartado(apartado: a), const SizedBox(height: 12)],
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.avance, required this.falta, required this.activos});
  final double avance;
  final double falta;
  final int activos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _Anillo(avance),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(avance * 100).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const Text('pagado', style: TextStyle(color: AppColors.textoSuave, fontSize: 10.5)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Te falta por pagar', style: TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                Text(
                  formatoPrecioCompleto(falta),
                  style: const TextStyle(color: AppColors.primario, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
                ),
                Text(
                  'en $activos ${activos == 1 ? 'apartado activo' : 'apartados activos'}',
                  style: const TextStyle(color: AppColors.textoSuave, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Anillo extends CustomPainter {
  const _Anillo(this.avance);
  final double avance;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final area = rect.deflate(6);
    canvas.drawArc(
      area,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = AppColors.superficie2,
    );
    canvas.drawArc(
      area,
      -math.pi / 2,
      2 * math.pi * avance,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(colors: [AppColors.primario, AppColors.lila, AppColors.primario]).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_Anillo old) => old.avance != avance;
}

class _TarjetaApartado extends StatelessWidget {
  const _TarjetaApartado({required this.apartado});
  final Apartado apartado;

  // Estado del apartado como en 10a: al corriente, días que faltan o su estado final.
  (String, TonoEstado, IconData?) get _chip {
    final a = apartado;
    if (a.estado == 'liquidado') return ('Liquidado', TonoEstado.exito, null);
    if (a.estado == 'cancelado') return ('Cancelado', TonoEstado.error, null);
    if (a.estado == 'pendiente_pago') return ('Pago inicial pendiente', TonoEstado.aviso, null);
    final dias = a.fechaLimite == null ? null : diasHasta(a.fechaLimite!);
    if (dias != null && dias <= 3) return (dias == 0 ? 'Vence hoy' : '$dias ${dias == 1 ? 'día' : 'días'}', TonoEstado.aviso, Icons.schedule_rounded);
    return ('Al corriente', TonoEstado.exito, null);
  }

  @override
  Widget build(BuildContext context) {
    final a = apartado;
    final (texto, tono, icono) = _chip;
    final pieza = a.piezas.isEmpty ? null : a.piezas.first;
    final nombre = pieza == null ? 'Apartado' : (a.piezas.length > 1 ? '${pieza.nombre} y ${a.piezas.length - 1} más' : pieza.nombre);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        children: [
          Row(
            children: [
              FotoPieza(url: pieza?.imagen, tamano: 58, radio: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      [a.folio, if (a.fechaLimite != null) 'vence ${fechaCorta(a.fechaLimite!)}', ?a.plan].join(' · '),
                      style: const TextStyle(color: AppColors.textoSuave, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ChipEstado(texto, tono: tono, icono: icono),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatoPrecioCompleto(a.montoPagado)} de ${formatoPrecioCompleto(a.montoTotal)}',
                  style: const TextStyle(color: AppColors.textoSuave, fontSize: 11.5),
                ),
              ),
              Text(
                a.saldo <= 0.009 ? 'Liquidado' : 'Faltan ${formatoPrecioCompleto(a.saldo)}',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 7, color: AppColors.superficie2),
                FractionallySizedBox(
                  widthFactor: a.avance,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: tono == TonoEstado.aviso ? colorAviso : null,
                      gradient: tono == TonoEstado.aviso ? null : const LinearGradient(colors: [AppColors.primario, AppColors.lila]),
                    ),
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
