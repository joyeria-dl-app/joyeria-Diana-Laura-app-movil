import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pedido.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../utils/pago_en_linea.dart';
import '../widgets/estado_pedido.dart';
import 'mis_pedidos_screen.dart';
import 'resultado_pago_screen.dart';

// Abre WhatsApp con la tienda y un mensaje ya escrito.
Future<void> abrirWhatsApp(BuildContext context, String mensaje) async {
  final mensajero = ScaffoldMessenger.of(context);
  try {
    final numero = await context.read<PedidoService>().whatsappTienda();
    if (numero == null) throw const PedidoException('La tienda no tiene WhatsApp registrado.');
    final ok = await launchUrl(Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}'), mode: LaunchMode.externalApplication);
    if (!ok) throw const PedidoException('No se pudo abrir WhatsApp.');
  } on PedidoException catch (e) {
    mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.mensaje)));
  }
}

// Seguimiento de un pedido (boceto 7b, estados 9c, 9d y 9e de Bocetos_Sprint3).
class SeguimientoScreen extends StatefulWidget {
  const SeguimientoScreen({super.key, required this.pedido});
  final Pedido pedido;

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  late Pedido _pedido = widget.pedido;
  bool _subiendo = false;
  bool _pagando = false;
  // Se abrió Mercado Pago: al volver a la app se consulta otra vez el pedido.
  bool _esperandoPago = false;
  StreamSubscription<Uri>? _enlaces;
  late final AppLifecycleListener _ciclo = AppLifecycleListener(onResume: _alVolver);

  @override
  void initState() {
    super.initState();
    _ciclo;
  }

  @override
  void dispose() {
    _ciclo.dispose();
    _enlaces?.cancel();
    super.dispose();
  }

  Future<void> _pagar() async {
    final servicio = context.read<PedidoService>();
    setState(() => _pagando = true);
    // Escucha el enlace de regreso antes de salir de la app para no perderlo.
    _enlaces?.cancel();
    _enlaces = enlacesDeRegreso().listen((uri) {
      final regreso = RegresoPago.desde(uri);
      if (regreso != null && regreso.tipo == 'pedido' && regreso.id == _pedido.id) _mostrarResultado(regreso.pago);
    });
    final abierta = await abrirPagoMercadoPago(context, () => servicio.preferenciaPedido(_pedido.id));
    if (mounted) setState(() => _pagando = false);
    _esperandoPago = abierta;
    if (!abierta) _enlaces?.cancel();
  }

  // Si el cliente vuelve sin pasar por el enlace de Mercado Pago, se revisa solo el servidor.
  Future<void> _alVolver() async {
    if (!_esperandoPago) return;
    await Future<void>.delayed(const Duration(seconds: 2));
    if (_esperandoPago) await _mostrarResultado(null);
  }

  // HU-12 (#43): consulta el pedido y muestra si el pago quedó aprobado, pendiente o rechazado.
  Future<void> _mostrarResultado(String? regreso) async {
    if (!_esperandoPago) return;
    _esperandoPago = false;
    await _enlaces?.cancel();
    if (!mounted) return;
    try {
      final nuevo = (await context.read<PedidoService>().misPedidos()).where((p) => p.id == _pedido.id).firstOrNull;
      if (!mounted || nuevo == null) return;
      setState(() => _pedido = nuevo);
      final resultado = resultadoDelPago(pagadoEnServidor: nuevo.pagado, regreso: regreso);
      if (resultado == null) {
        _avisar('No vimos tu pago. Si ya pagaste, en unos momentos se verá aquí.');
        return;
      }
      final reintentar = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ResultadoPagoScreen(resultado: resultado, folio: nuevo.folio, monto: nuevo.total),
        ),
      );
      if (reintentar == true && mounted) await _pagar();
    } on PedidoException catch (e) {
      _avisar(e.mensaje);
    }
  }

  void _avisar(String texto) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _subirComprobante() async {
    final servicio = context.read<PedidoService>();
    final foto = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
    if (foto == null) return;
    setState(() => _subiendo = true);
    try {
      await servicio.subirComprobante(_pedido.id, await foto.readAsBytes(), foto.name);
      final actualizados = await servicio.misPedidos();
      final nuevo = actualizados.where((p) => p.id == _pedido.id).firstOrNull;
      if (!mounted) return;
      setState(() => _pedido = nuevo ?? _pedido);
      _avisar('Recibimos tu comprobante. Te avisaremos cuando lo verifiquemos.');
    } on PedidoException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _pedido;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(top: 0, left: 0, right: 0, child: _Encabezado(icono: p.domicilio ? Icons.local_shipping_outlined : Icons.storefront_outlined)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  _BotonClaro(icono: Icons.arrow_back_rounded, descripcion: 'Regresar', onPressed: () => Navigator.maybePop(context)),
                  const Spacer(),
                  _BotonClaro(
                    icono: Icons.chat_outlined,
                    descripcion: 'Escribir a la tienda',
                    onPressed: () => abrirWhatsApp(context, 'Hola, tengo una duda sobre mi pedido ${p.folio}.'),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: 210,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.fondo,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Pedido ${p.folio}', style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                      ),
                      ChipEstado.pedido(p.estado),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(tituloPedido(p), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                  const SizedBox(height: 14),
                  ..._tarjeta(p),
                  const SizedBox(height: 18),
                  const Text(
                    'Historial',
                    style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  LineaTiempo(pasos: pasosDe(p), error: p.cancelado),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Lo que guarda el pedido según su momento: guía (9c), código de entrega (9d) o comprobante (9e).
  List<Widget> _tarjeta(Pedido p) {
    // HU-12: pedido confirmado con Mercado Pago y todavía sin pagar.
    if (p.puedePagarEnLinea) {
      return [
        _Tarjeta(
          icono: Icons.credit_card_rounded,
          titulo: 'Paga con Mercado Pago',
          texto: 'Tu pedido ya está confirmado · ${formatoPrecioCompleto(p.total)}',
          accion: _pagando
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primario))
              : _BotonAccion(icono: Icons.open_in_new_rounded, descripcion: 'Pagar con Mercado Pago', onPressed: _pagar),
        ),
      ];
    }
    if (p.esperaComprobante) {
      return [
        _Tarjeta(
          icono: Icons.upload_file_outlined,
          titulo: 'Sube tu comprobante',
          texto: 'Lo verificamos y confirmamos tu pedido',
          accion: _subiendo
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primario))
              : _BotonAccion(icono: Icons.add_photo_alternate_outlined, descripcion: 'Elegir foto del comprobante', onPressed: _subirComprobante),
        ),
      ];
    }
    if (p.metodoPagoCodigo == 'transferencia' && p.comprobanteUrl != null && p.estado == 'pendiente') {
      return [const _Tarjeta(icono: Icons.task_alt_rounded, titulo: 'Comprobante enviado', texto: 'Lo estamos verificando')];
    }
    if (p.numeroGuia != null && p.numeroGuia!.isNotEmpty) {
      return [
        _Tarjeta(
          icono: Icons.local_shipping_outlined,
          titulo: 'Guía ${p.numeroGuia}',
          texto: [?p.paqueteria, if (p.direccion != null) 'a ${p.direccion!.split(',').take(2).join(',')}'].join(' · '),
          accion: _BotonAccion(
            icono: Icons.copy_rounded,
            descripcion: 'Copiar guía',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: p.numeroGuia!));
              _avisar('Guía copiada');
            },
          ),
        ),
      ];
    }
    if (!p.domicilio && p.codigoEntrega != null && !p.terminado) {
      return [_Tarjeta(icono: Icons.qr_code_2_rounded, titulo: 'Código de entrega: ${p.codigoEntrega}', texto: 'Muéstralo al recoger tu pedido')];
    }
    return const [];
  }
}

// Parte de arriba con el degradado y el pin (.map de los bocetos 9c–9e).
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.icono});
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7E5A8E), Color(0xFFB8708F)]),
              ),
            ),
          ),
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(color: Color(0x14FFFFFF), shape: BoxShape.circle),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.05),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primario, AppColors.primario2]),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  child: Icon(icono, size: 24, color: Colors.white),
                ),
                Transform.translate(
                  offset: const Offset(0, -8),
                  child: Transform.rotate(angle: 0.785, child: Container(width: 16, height: 16, color: AppColors.primario2)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonClaro extends StatelessWidget {
  const _BotonClaro({required this.icono, required this.descripcion, required this.onPressed});
  final IconData icono;
  final String descripcion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: descripcion,
      child: Material(
        color: const Color(0x33FFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icono, size: 20, color: Colors.white)),
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.icono, required this.titulo, required this.texto, this.accion});
  final IconData icono;
  final String titulo;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(14)),
            child: Icon(icono, size: 21, color: AppColors.primario),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (texto.isNotEmpty) Text(texto, style: const TextStyle(color: AppColors.textoSuave, fontSize: 11)),
              ],
            ),
          ),
          if (accion != null) ...[const SizedBox(width: 8), accion!],
        ],
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({required this.icono, required this.descripcion, required this.onPressed});
  final IconData icono;
  final String descripcion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: descripcion,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primario, AppColors.primario2]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: SizedBox(width: 40, height: 40, child: Icon(icono, size: 20, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
