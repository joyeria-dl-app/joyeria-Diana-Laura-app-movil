import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pedido.dart';
import '../providers/carrito_provider.dart';
import '../routes/app_routes.dart';
import '../services/pedido_service.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../widgets/decoracion.dart';
import '../widgets/pasos_pedido.dart';
import 'pedido_listo_screen.dart';

// Color de los avisos del servidor en los bocetos (--warn).
const _aviso = Color(0xFFF6A723);

// Confirmar compra o apartado (boceto P10, estados 8a–8d y 8g de Bocetos_Sprint3).
class ConfirmarPedidoScreen extends StatefulWidget {
  const ConfirmarPedidoScreen({super.key});

  @override
  State<ConfirmarPedidoScreen> createState() => _ConfirmarPedidoScreenState();
}

class _ConfirmarPedidoScreenState extends State<ConfirmarPedidoScreen> {
  OpcionesCompra? _opciones;
  List<String> _zonas = const [];
  List<PlanAbono> _planes = const [];
  String? _errorCarga;

  bool _apartado = false;
  bool _domicilio = false;
  DireccionEntrega? _direccion;
  MetodoPago? _metodo;
  // Porcentaje del total que se abona hoy: 50, 75 o 100.
  int _porcentaje = 50;
  PlanAbono? _plan;

  bool _enviando = false;
  // Mensaje del servidor al confirmar, por ejemplo sin existencias (8g).
  String? _avisoServidor;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _errorCarga = null);
    final servicio = context.read<PedidoService>();
    try {
      final resultados = await Future.wait([servicio.opciones(), servicio.zonas(), servicio.planes()]);
      if (!mounted) return;
      setState(() {
        _opciones = resultados[0] as OpcionesCompra;
        _zonas = resultados[1] as List<String>;
        _planes = resultados[2] as List<PlanAbono>;
        _elegirMetodoValido();
      });
    } on PedidoException catch (e) {
      if (mounted) setState(() => _errorCarga = e.mensaje);
    }
  }

  List<MetodoPago> get _metodos => _opciones?.metodosPara(domicilio: !_apartado && _domicilio) ?? const [];

  // Al cambiar de entrega, el efectivo deja de servir a domicilio.
  void _elegirMetodoValido() {
    if (_metodo == null || !_metodos.any((m) => m.id == _metodo!.id)) {
      // Como en el boceto 8a: efectivo si aplica; si no, el primero.
      _metodo = _metodos.where((m) => m.soloEnTienda).firstOrNull ?? _metodos.firstOrNull;
    }
  }

  double get _subtotal => context.read<CarritoProvider>().subtotal;
  double get _envio => !_apartado && _domicilio ? (_opciones?.costoEnvio ?? 0) : 0;
  double get _total => _subtotal + _envio;
  double get _abonoHoy => double.parse((_subtotal * _porcentaje / 100).toStringAsFixed(2));

  // Las zonas son nombres cortos ("Huejutla"); la ciudad puede ser "Huejutla de Reyes".
  bool get _enZona {
    final ciudad = _sinAcentos(_direccion?.ciudad ?? '');
    return _zonas.any((z) => ciudad.contains(_sinAcentos(z)));
  }

  bool get _puedeConfirmar {
    if (_metodo == null || _enviando) return false;
    if (!_apartado && _domicilio) return _direccion != null && _enZona;
    return true;
  }

  Future<void> _pedirDireccion() async {
    final direccion = await showModalBottomSheet<DireccionEntrega>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.fondo,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => HojaDireccion(zonas: _zonas, inicial: _direccion),
    );
    if (direccion != null && mounted) setState(() => _direccion = direccion);
  }

  Future<void> _elegirDomicilio(bool domicilio) async {
    setState(() {
      _domicilio = domicilio;
      _avisoServidor = null;
      _elegirMetodoValido();
    });
    if (domicilio && _direccion == null) await _pedirDireccion();
  }

  Future<void> _confirmar() async {
    final servicio = context.read<PedidoService>();
    final carrito = context.read<CarritoProvider>();
    final navegador = Navigator.of(context);
    final piezas = carrito.piezas;
    final total = _total;
    final metodo = _metodo!;
    setState(() {
      _enviando = true;
      _avisoServidor = null;
    });
    try {
      final PedidoListo listo;
      if (_apartado) {
        final abono = _abonoHoy;
        final hecho = await servicio.apartar(metodo: metodo, abonoHoy: abono, plan: _plan);
        // La fecha límite y el estado los define el backend; se leen del apartado recién creado.
        Apartado? creado;
        try {
          creado = (await servicio.misApartados()).where((a) => a.folio == hecho.folio).firstOrNull;
        } on PedidoException {
          creado = null;
        }
        listo = PedidoListo.apartado(
          folio: hecho.folio,
          abonoHoy: abono,
          saldo: creado?.saldo ?? total - abono,
          plan: _plan?.nombre,
          fechaLimite: creado?.fechaLimite,
        );
      } else {
        final hecho = await servicio.comprar(metodo: metodo, direccion: _domicilio ? _direccion : null, costoEnvio: _envio);
        listo = PedidoListo.compra(folio: hecho.folio, piezas: piezas, domicilio: _domicilio, metodo: metodo.nombre, total: total);
      }
      // El backend vació el carrito al crear el pedido.
      await carrito.cargar();
      navegador.pushReplacement(MaterialPageRoute(builder: (_) => PedidoListoScreen(listo: listo)));
    } on PedidoException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      if (e.sinSesion) {
        navegador.pushNamed(AppRoutes.login);
        return;
      }
      setState(() => _avisoServidor = e.mensaje);
      // Puede que alguien más haya comprado la pieza: se trae el carrito real.
      carrito.cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CarritoProvider>();
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          const Destellos(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Encabezado(titulo: _apartado ? 'Apartar piezas' : 'Confirmar pedido'),
                Expanded(child: _contenido()),
              ],
            ),
          ),
          if (_opciones != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BarraConfirmar(
                etiqueta: _apartado ? 'Abono de hoy' : 'Total',
                monto: _apartado ? _abonoHoy : _total,
                boton: _apartado ? 'Apartar' : 'Confirmar',
                enviando: _enviando,
                onConfirmar: _puedeConfirmar ? _confirmar : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_errorCarga != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.primario),
              const SizedBox(height: 12),
              Text(
                _errorCarga!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_opciones == null) return const Center(child: CircularProgressIndicator(color: AppColors.primario));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
      children: [
        const PasosPedido(actual: 2),
        const SizedBox(height: 16),
        _Pestanas(
          apartado: _apartado,
          onChanged: (apartado) => setState(() {
            _apartado = apartado;
            _avisoServidor = null;
            _elegirMetodoValido();
          }),
        ),
        const SizedBox(height: 16),
        ...(_apartado ? _apartar() : _comprar()),
        if (_avisoServidor != null) ...[const SizedBox(height: 14), _AvisoServidor(_avisoServidor!)],
      ],
    );
  }

  // 8a y 8b.
  List<Widget> _comprar() {
    final metodo = _metodo;
    return [
      Row(
        children: [
          Expanded(
            child: _OpcionEntrega(
              icono: Icons.storefront_outlined,
              titulo: 'En tienda',
              detalle: 'Gratis',
              elegida: !_domicilio,
              onTap: () => _elegirDomicilio(false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _OpcionEntrega(
              icono: Icons.local_shipping_outlined,
              titulo: 'A domicilio',
              detalle: '+${formatoPrecioCompleto(_opciones!.costoEnvio)}',
              elegida: _domicilio,
              onTap: () => _elegirDomicilio(true),
            ),
          ),
        ],
      ),
      if (_domicilio) ...[
        const SizedBox(height: 14),
        _TarjetaDireccion(direccion: _direccion, envio: _opciones!.costoEnvio, onTap: _pedirDireccion),
        if (_direccion != null) ...[
          const SizedBox(height: 8),
          _enZona
              ? const _Nota(icono: Icons.check_circle_outline_rounded, texto: 'Entregamos en tu zona.', color: AppColors.texto)
              : _Nota(icono: Icons.info_outline_rounded, texto: 'Por ahora solo entregamos en ${_lista(_zonas)}.', color: _aviso),
        ],
      ],
      const SizedBox(height: 16),
      const _Subtitulo('Método de pago'),
      const SizedBox(height: 10),
      ..._listaMetodos(),
      if (metodo != null) ...[const SizedBox(height: 4), _Nota(icono: Icons.info_outline_rounded, texto: _explicacion(metodo), color: AppColors.textoSuave)],
    ];
  }

  // 8d.
  List<Widget> _apartar() {
    final saldo = _subtotal - _abonoHoy;
    return [
      const _Subtitulo('¿Cuánto abonas hoy?'),
      const SizedBox(height: 10),
      _Abono(
        porcentaje: _porcentaje,
        monto: _abonoHoy,
        onChanged: (p) => setState(() {
          _porcentaje = p;
          if (p == 100) _plan = null;
        }),
      ),
      const SizedBox(height: 8),
      _Nota(
        icono: Icons.info_outline_rounded,
        texto: saldo <= 0.009
            ? 'Pagas todo hoy y recoges tus piezas en tienda.'
            : 'Mínimo ${formatoPrecioCompleto(_subtotal / 2)} (50%). Te quedaría ${formatoPrecioCompleto(saldo)} por pagar.',
        color: AppColors.textoSuave,
      ),
      if (saldo > 0.009 && _planes.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text.rich(
          TextSpan(
            text: 'Elige cómo liquidar',
            style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5, fontWeight: FontWeight.w500),
            children: [
              TextSpan(
                text: ' (opcional)',
                style: TextStyle(fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final plan in _planes) ...[
          _Eleccion(
            icono: const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.textoSuave),
            titulo: plan.nombre,
            detalle: _detallePlan(plan),
            elegida: _plan?.id == plan.id,
            // Se puede quitar el plan tocándolo otra vez.
            onTap: () => setState(() => _plan = _plan?.id == plan.id ? null : plan),
          ),
          const SizedBox(height: 10),
        ],
      ],
      const SizedBox(height: 6),
      const _Subtitulo('¿Cómo pagas el abono?'),
      const SizedBox(height: 10),
      ..._listaMetodos(),
      const SizedBox(height: 4),
      const _Nota(
        icono: Icons.storefront_outlined,
        texto: 'Tus piezas quedan reservadas para ti y se recogen en tienda al liquidar.',
        color: AppColors.textoSuave,
      ),
    ];
  }

  List<Widget> _listaMetodos() => [
    for (final m in _metodos) ...[
      _Eleccion(
        icono: _IconoMetodo(m.codigo),
        titulo: _nombreMetodo(m),
        detalle: _detalleMetodo(m.codigo),
        elegida: _metodo?.id == m.id,
        onTap: () => setState(() {
          _metodo = m;
          _avisoServidor = null;
        }),
      ),
      const SizedBox(height: 10),
    ],
  ];

  String _detallePlan(PlanAbono plan) {
    final pagos = plan.pagos(total: _subtotal, abonoHoy: _abonoHoy);
    if (pagos.isEmpty) return 'Sin pagos pendientes';
    final monto = formatoPrecioCompleto(pagos.first);
    return pagos.length == 1 ? '1 pago de $monto a los ${plan.intervaloDias} días' : '${pagos.length} pagos de $monto cada ${plan.intervaloDias} días';
  }
}

String _sinAcentos(String texto) =>
    texto.toLowerCase().replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u');

// "Huejutla, San Felipe y Tampico".
String _lista(List<String> nombres) => nombres.length < 2 ? nombres.join() : '${nombres.sublist(0, nombres.length - 1).join(', ')} y ${nombres.last}';

String _nombreMetodo(MetodoPago m) => switch (m.codigo) {
  'efectivo' => 'Efectivo en tienda',
  'transferencia' => 'Transferencia',
  'mercadopago' => 'Mercado Pago',
  _ => m.nombre,
};

String _detalleMetodo(String codigo) => switch (codigo) {
  'efectivo' => 'Pagas al recoger',
  'transferencia' => 'Envías tu comprobante',
  'mercadopago' => 'Tarjeta, OXXO o saldo',
  'paypal' => 'Cuenta o tarjeta',
  _ => '',
};

String _explicacion(MetodoPago m) => switch (m.codigo) {
  'efectivo' => 'Pagas en efectivo al recoger tu pedido en la tienda.',
  'transferencia' => 'Cuando confirmemos tu pedido, te enviamos los datos para la transferencia.',
  _ => 'Cuando confirmemos tu pedido, te llevamos a ${_nombreMetodo(m)} para pagar.',
};

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          BotonCristal(icono: Icons.arrow_back_rounded, descripcion: 'Regresar', onPressed: () => Navigator.maybePop(context)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 44),
              child: Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Selector Compra | Apartado.
class _Pestanas extends StatelessWidget {
  const _Pestanas({required this.apartado, required this.onChanged});
  final bool apartado;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget pestana(String texto, bool elegida, bool valor) => Expanded(
      child: Semantics(
        selected: elegida,
        button: true,
        child: GestureDetector(
          onTap: () => onChanged(valor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: elegida ? AppColors.fondo : Colors.transparent, borderRadius: BorderRadius.circular(16)),
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: elegida ? FontWeight.w600 : FontWeight.w400,
                color: elegida ? AppColors.texto : AppColors.textoSuave,
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [pestana('Compra', !apartado, false), pestana('Apartado', apartado, true)]),
    );
  }
}

class _OpcionEntrega extends StatelessWidget {
  const _OpcionEntrega({required this.icono, required this.titulo, required this.detalle, required this.elegida, required this.onTap});
  final IconData icono;
  final String titulo;
  final String detalle;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: elegida,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: elegida ? const Color(0x14FF8CC6) : AppColors.superficie,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: elegida ? AppColors.primario : AppColors.borde, width: elegida ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: elegida ? null : AppColors.superficie2,
                      gradient: elegida ? const LinearGradient(colors: [AppColors.primario, AppColors.primario2]) : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icono, size: 20, color: elegida ? Colors.white : AppColors.texto),
                  ),
                  const Spacer(),
                  if (elegida) const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primario),
                ],
              ),
              const SizedBox(height: 14),
              Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(detalle, style: const TextStyle(color: AppColors.textoSuave, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaDireccion extends StatelessWidget {
  const _TarjetaDireccion({required this.direccion, required this.envio, required this.onTap});
  final DireccionEntrega? direccion;
  final double envio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = direccion;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borde),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.location_on_outlined, size: 22, color: AppColors.primario),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d == null ? 'Agrega tu dirección' : '${d.calle} ${d.numero}'.trim(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    d == null ? 'Para calcular la entrega' : '${d.colonia}, ${d.ciudad.split(' ').first} · envío ${formatoPrecio(envio)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textoSuave, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(d == null ? Icons.add_rounded : Icons.edit_outlined, size: 20, color: AppColors.textoSuave),
          ],
        ),
      ),
    );
  }
}

// Renglón con radio para métodos de pago y planes.
class _Eleccion extends StatelessWidget {
  const _Eleccion({required this.icono, required this.titulo, required this.detalle, required this.elegida, required this.onTap});
  final Widget icono;
  final String titulo;
  final String detalle;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: elegida,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: elegida ? const Color(0x14FF8CC6) : AppColors.superficie,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: elegida ? AppColors.primario : AppColors.borde, width: elegida ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(14)),
                child: icono,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    if (detalle.isNotEmpty) Text(detalle, style: const TextStyle(color: AppColors.textoSuave, fontSize: 11)),
                  ],
                ),
              ),
              _Radio(elegido: elegida),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.elegido});
  final bool elegido;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: elegido ? AppColors.primario : AppColors.textoSuave, width: 1.8),
      ),
      child: elegido
          ? const DecoratedBox(
              decoration: BoxDecoration(color: AppColors.primario, shape: BoxShape.circle),
            )
          : null,
    );
  }
}

// Íconos de los bocetos: billete, banco y las insignias MP y PP.
class _IconoMetodo extends StatelessWidget {
  const _IconoMetodo(this.codigo);
  final String codigo;

  @override
  Widget build(BuildContext context) {
    Widget insignia(String texto, Color color) => Container(
      width: 30,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
    return switch (codigo) {
      'mercadopago' => insignia('MP', const Color(0xFF00B1EA)),
      'paypal' => insignia('PP', const Color(0xFF003087)),
      'transferencia' => const Icon(Icons.account_balance_outlined, size: 20, color: AppColors.textoSuave),
      _ => const Icon(Icons.payments_outlined, size: 20, color: AppColors.textoSuave),
    };
  }
}

// Anillo con el porcentaje, el monto y los botones 50% · 75% · Todo (8d).
class _Abono extends StatelessWidget {
  const _Abono({required this.porcentaje, required this.monto, required this.onChanged});
  final int porcentaje;
  final double monto;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget opcion(String texto, int valor) {
      final elegida = porcentaje == valor;
      return Semantics(
        selected: elegida,
        button: true,
        child: GestureDetector(
          onTap: () => onChanged(valor),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: elegida ? null : AppColors.superficie2,
              gradient: elegida ? const LinearGradient(colors: [AppColors.primario, AppColors.primario2]) : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              texto,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: elegida ? Colors.white : AppColors.texto),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            height: 66,
            child: CustomPaint(
              painter: _Anillo(porcentaje / 100),
              child: Center(
                child: Text('$porcentaje%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatoPrecioCompleto(monto), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [opcion('50%', 50), opcion('75%', 75), opcion('Todo', 100)]),
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
    final area = rect.deflate(4);
    canvas.drawArc(
      area,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = AppColors.superficie2,
    );
    canvas.drawArc(
      area,
      -math.pi / 2,
      2 * math.pi * avance,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(colors: [AppColors.primario, AppColors.primario2, AppColors.primario]).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_Anillo old) => old.avance != avance;
}

class _Subtitulo extends StatelessWidget {
  const _Subtitulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: const TextStyle(color: AppColors.textoSuave, fontSize: 12.5, fontWeight: FontWeight.w500),
  );
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icono, required this.texto, required this.color});
  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icono, size: 15, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(texto, style: TextStyle(color: color, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

// Boceto 8g: el servidor rechazó el pedido.
class _AvisoServidor extends StatelessWidget {
  const _AvisoServidor(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: const Color(0x26F6A723), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: _aviso),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: _aviso, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// Barra inferior de vidrio con el total y Confirmar o Apartar.
class BarraConfirmar extends StatelessWidget {
  const BarraConfirmar({super.key, required this.etiqueta, required this.monto, required this.boton, required this.onConfirmar, this.enviando = false});

  final String etiqueta;
  final double monto;
  final String boton;
  final VoidCallback? onConfirmar;
  final bool enviando;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        padding: const EdgeInsets.fromLTRB(22, 8, 8, 8),
        decoration: BoxDecoration(
          color: const Color(0xE6281224),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x2EFFAAD7)),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 20), spreadRadius: -10)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    etiqueta,
                    style: const TextStyle(color: AppColors.textoSuave, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  Text(formatoPrecioCompleto(monto), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                ],
              ),
            ),
            Opacity(
              opacity: onConfirmar == null && !enviando ? 0.5 : 1,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.degradado, borderRadius: BorderRadius.circular(22)),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: onConfirmar,
                    child: SizedBox(
                      height: 54,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: enviando
                            ? const Center(
                                child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    boton,
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Boceto 8c: hoja para capturar la dirección de entrega.
class HojaDireccion extends StatefulWidget {
  const HojaDireccion({super.key, required this.zonas, this.inicial});
  final List<String> zonas;
  final DireccionEntrega? inicial;

  @override
  State<HojaDireccion> createState() => _HojaDireccionState();
}

class _HojaDireccionState extends State<HojaDireccion> {
  final _form = GlobalKey<FormState>();
  late final _calle = TextEditingController(text: widget.inicial?.calle);
  late final _numero = TextEditingController(text: widget.inicial?.numero);
  late final _interior = TextEditingController(text: widget.inicial?.numeroInterior);
  late final _colonia = TextEditingController(text: widget.inicial?.colonia);
  late final _cp = TextEditingController(text: widget.inicial?.codigoPostal);
  late final _ciudad = TextEditingController(text: widget.inicial?.ciudad);
  late final _referencias = TextEditingController(text: widget.inicial?.referencias);

  @override
  void dispose() {
    for (final c in [_calle, _numero, _interior, _colonia, _cp, _ciudad, _referencias]) {
      c.dispose();
    }
    super.dispose();
  }

  void _usar() {
    if (!_form.currentState!.validate()) return;
    String? opcional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    Navigator.pop(
      context,
      DireccionEntrega(
        calle: _calle.text.trim(),
        numero: _numero.text.trim(),
        numeroInterior: opcional(_interior),
        colonia: _colonia.text.trim(),
        ciudad: _ciudad.text.trim(),
        codigoPostal: _cp.text.trim(),
        referencias: opcional(_referencias),
      ),
    );
  }

  String? _requerido(String? v) => (v ?? '').trim().isEmpty ? 'Requerido' : null;

  @override
  Widget build(BuildContext context) {
    Widget campo(TextEditingController c, String hint, IconData icono, {FormFieldValidator<String>? validar, TextInputType? teclado}) => TextFormField(
      controller: c,
      validator: validar,
      keyboardType: teclado,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(color: AppColors.texto, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icono, size: 20)),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
          child: Form(
            key: _form,
            child: Column(
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
                const Text('Tu dirección de entrega', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Entregamos en ${_lista(widget.zonas)}.', style: const TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                const SizedBox(height: 14),
                campo(_calle, 'Calle', Icons.signpost_outlined, validar: _requerido),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: campo(_numero, 'Número', Icons.tag_rounded, validar: _requerido)),
                    const SizedBox(width: 10),
                    Expanded(child: campo(_interior, 'Interior (opcional)', Icons.apartment_outlined)),
                  ],
                ),
                const SizedBox(height: 10),
                campo(_colonia, 'Colonia', Icons.location_city_outlined, validar: _requerido),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: campo(
                        _cp,
                        'C.P.',
                        Icons.markunread_mailbox_outlined,
                        teclado: TextInputType.number,
                        validar: (v) => RegExp(r'^\d{5}$').hasMatch((v ?? '').trim()) ? null : '5 dígitos',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: campo(_ciudad, 'Ciudad', Icons.map_outlined, validar: _requerido)),
                  ],
                ),
                const SizedBox(height: 10),
                campo(_referencias, 'Referencias (opcional)', Icons.notes_rounded),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.degradado, borderRadius: BorderRadius.circular(18)),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _usar,
                      child: const SizedBox(
                        height: 52,
                        child: Center(
                          child: Text(
                            'Usar esta dirección',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
