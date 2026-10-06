import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/pedido.dart';
import '../routes/app_routes.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../utils/fechas.dart';
import '../utils/formato.dart';
import '../widgets/decoracion.dart';
import '../widgets/estado_pedido.dart';

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

  void _avisar(String texto) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));

  // Registrar un abono como en el sitio web: se elige el apartado, el monto y cómo se paga.
  Future<void> _abonar() async {
    final abonables = _activos.where((a) => a.puedeAbonar).toList();
    if (abonables.isEmpty) {
      final a = _activos.first;
      _avisar(
        a.abonoPorConfirmar
            ? 'Ya enviaste un abono. Podrás hacer otro cuando la tienda lo confirme.'
            : 'Podrás abonar cuando la tienda confirme tu pago inicial.',
      );
      return;
    }
    final servicio = context.read<PedidoService>();
    try {
      final opciones = await servicio.opciones();
      if (!mounted) return;
      final enviado = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.fondo,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        builder: (_) => Provider<PedidoService>.value(
          value: servicio,
          child: HojaAbono(apartados: abonables, metodos: opciones.metodos),
        ),
      );
      if (enviado == true) {
        _avisar('Recibimos tu abono. La tienda lo confirmará en breve.');
        _cargar();
      }
    } on PedidoException catch (e) {
      _avisar(e.mensaje);
    }
  }

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
                'Cuando liquidas, las recoges en la tienda. Tus abonos los registras aquí con transferencia o en la tienda, y la tienda los confirma.',
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
                    child: BotonDegradado(texto: 'Abonar', icono: Icons.payments_outlined, ancho: true, onPressed: _abonar),
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
    if (a.abonoPorConfirmar) return ('Abono por confirmar', TonoEstado.aviso, Icons.hourglass_top_rounded);
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

// Hoja para registrar un abono: apartado, monto y forma de pago, como en el sitio web.
class HojaAbono extends StatefulWidget {
  const HojaAbono({super.key, required this.apartados, required this.metodos});
  final List<Apartado> apartados;
  final List<MetodoPago> metodos;

  @override
  State<HojaAbono> createState() => _HojaAbonoState();
}

class _HojaAbonoState extends State<HojaAbono> {
  late Apartado _apartado = widget.apartados.first;
  bool _todo = false;
  late MetodoPago? _metodo = widget.metodos.where((m) => m.codigo == 'transferencia').firstOrNull;
  bool _enviando = false;
  String? _error;

  double get _monto => _todo ? _apartado.saldo : _apartado.abonoSugerido;

  Future<void> _enviar() async {
    final metodo = _metodo!;
    final servicio = context.read<PedidoService>();
    List<int>? bytes;
    String? nombre;
    if (metodo.codigo == 'transferencia') {
      final foto = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
      if (foto == null) return;
      bytes = await foto.readAsBytes();
      nombre = foto.name;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await servicio.solicitarAbono(_apartado.id, monto: _monto, metodo: metodo, comprobante: bytes, nombreArchivo: nombre);
      if (mounted) Navigator.pop(context, true);
    } on PedidoException catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _error = e.mensaje;
        });
      }
    }
  }

  String _nombre(MetodoPago m) => switch (m.codigo) {
    'efectivo' => 'Efectivo en tienda',
    'transferencia' => 'Transferencia',
    'mercadopago' => 'Mercado Pago',
    _ => m.nombre,
  };

  String _detalle(MetodoPago m) => switch (m.codigo) {
    'efectivo' => 'Pagas en la tienda y ahí lo registran',
    'transferencia' => 'Subes la foto de tu comprobante',
    _ => 'Pago en línea muy pronto en la app',
  };

  @override
  Widget build(BuildContext context) {
    final metodo = _metodo;
    final enLinea = metodo?.enLinea ?? false;
    final transferencia = metodo?.codigo == 'transferencia';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Abonar a tu apartado', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (widget.apartados.length > 1) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in widget.apartados) _Opcion(texto: a.folio, elegida: a.id == _apartado.id, onTap: () => setState(() => _apartado = a)),
                ],
              ),
              const SizedBox(height: 14),
            ],
            const Text('¿Cuánto abonas?', style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _Opcion(
                    texto: _apartado.planPorcentaje == null ? 'Saldo' : 'Abono del plan',
                    detalle: formatoPrecioCompleto(_apartado.abonoSugerido),
                    elegida: !_todo,
                    onTap: () => setState(() => _todo = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Opcion(texto: 'Liquidar', detalle: formatoPrecioCompleto(_apartado.saldo), elegida: _todo, onTap: () => setState(() => _todo = true)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('¿Cómo pagas?', style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5)),
            const SizedBox(height: 8),
            for (final m in widget.metodos) ...[
              _Opcion(texto: _nombre(m), detalle: _detalle(m), elegida: m.id == metodo?.id, onTap: () => setState(() => _metodo = m)),
              const SizedBox(height: 8),
            ],
            if (_error != null) ...[const SizedBox(height: 4), Text(_error!, style: const TextStyle(color: colorAviso, fontSize: 12))],
            const SizedBox(height: 12),
            if (_enviando)
              const Center(child: CircularProgressIndicator(color: AppColors.primario))
            else
              Opacity(
                opacity: metodo == null || enLinea ? 0.5 : 1,
                child: BotonDegradado(
                  texto: transferencia ? 'Subir comprobante y enviar' : 'Avisar que pagaré en tienda',
                  icono: transferencia ? Icons.upload_file_outlined : Icons.storefront_outlined,
                  ancho: true,
                  onPressed: metodo == null || enLinea ? null : _enviar,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.texto, this.detalle, required this.elegida, required this.onTap});
  final String texto;
  final String? detalle;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: elegida,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: elegida ? const Color(0x14FF8CC6) : AppColors.superficie,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: elegida ? AppColors.primario : AppColors.borde, width: elegida ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (detalle != null) Text(detalle!, style: const TextStyle(color: AppColors.textoSuave, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
