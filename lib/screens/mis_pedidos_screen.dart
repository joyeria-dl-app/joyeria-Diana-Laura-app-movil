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

// Mis pedidos (boceto P11, estados 9a y 9b de Bocetos_Sprint3).
class MisPedidosScreen extends StatefulWidget {
  const MisPedidosScreen({super.key});

  @override
  State<MisPedidosScreen> createState() => _MisPedidosScreenState();
}

enum _Filtro { enCurso, entregados, cancelados }

class _MisPedidosScreenState extends State<MisPedidosScreen> {
  List<Pedido>? _pedidos;
  PedidoException? _error;
  _Filtro _filtro = _Filtro.enCurso;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final pedidos = await context.read<PedidoService>().misPedidos();
      if (mounted) {
        setState(() {
          _pedidos = pedidos;
          _error = null;
        });
      }
    } on PedidoException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  List<Pedido> _de(_Filtro f) => (_pedidos ?? const <Pedido>[])
      .where(
        (p) => switch (f) {
          _Filtro.enCurso => p.enCurso,
          _Filtro.entregados => p.entregado,
          _Filtro.cancelados => p.cancelado,
        },
      )
      .toList();

  Future<void> _abrir(Pedido p) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SeguimientoScreen(pedido: p)));
    // Al volver puede haber subido su comprobante.
    _cargar();
  }

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
                const Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, 0), child: TituloDegradado('Mis pedidos', tamano: 28)),
                const SizedBox(height: 14),
                if (_pedidos != null) _Filtros(actual: _filtro, cuenta: _de(_filtro).length, onChanged: (f) => setState(() => _filtro = f)),
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
              titulo: 'Inicia sesión para ver tus pedidos',
              texto: 'Con tu cuenta ves aquí los mismos pedidos que en el sitio web.',
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
    if (_pedidos == null) return const Center(child: CircularProgressIndicator(color: AppColors.primario));
    final lista = _de(_filtro);
    if (lista.isEmpty) {
      // 9b.
      return AvisoVacio(
        icono: Icons.receipt_long_outlined,
        titulo: switch (_filtro) {
          _Filtro.enCurso => 'Aún no tienes pedidos',
          _Filtro.entregados => 'Sin pedidos entregados',
          _Filtro.cancelados => 'Sin pedidos cancelados',
        },
        texto: _filtro == _Filtro.enCurso ? 'Cuando confirmes una compra, aquí verás en qué punto va.' : 'Aquí aparecerán cuando tengas alguno.',
        boton: _filtro == _Filtro.enCurso ? 'Ver catálogo' : null,
        iconoBoton: Icons.diamond_outlined,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.catalogo),
      );
    }
    return RefreshIndicator(
      color: AppColors.primario,
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          for (var i = 0; i < lista.length; i++) ...[
            // El primero en curso se muestra abierto con su línea de tiempo (9a).
            if (i == 0 && _filtro == _Filtro.enCurso)
              _PedidoAbierto(pedido: lista[i], onTap: () => _abrir(lista[i]))
            else
              _PedidoCerrado(pedido: lista[i], onTap: () => _abrir(lista[i])),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _Filtros extends StatelessWidget {
  const _Filtros({required this.actual, required this.cuenta, required this.onChanged});
  final _Filtro actual;
  final int cuenta;
  final ValueChanged<_Filtro> onChanged;

  static const _nombres = {_Filtro.enCurso: 'En curso', _Filtro.entregados: 'Entregados', _Filtro.cancelados: 'Cancelados'};

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (final f in _Filtro.values) ...[
            Semantics(
              selected: f == actual,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: f == actual ? AppColors.degradado : null,
                    color: f == actual ? null : AppColors.superficie,
                    borderRadius: BorderRadius.circular(20),
                    border: f == actual ? null : Border.all(color: AppColors.borde),
                  ),
                  child: Text(
                    f == actual ? '${_nombres[f]} · $cuenta' : _nombres[f]!,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: f == actual ? Colors.white : AppColors.texto),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// Título grande del pedido según su situación (9a–9e).
String tituloPedido(Pedido p, {bool corto = false}) {
  if (p.cancelado) return 'Pedido ${nombreEstado(p.estado).toLowerCase()}';
  if (p.entregado) {
    final f = p.fechaDe('entregado');
    return f == null ? 'Entregado' : 'Entregado el ${fechaCorta(f)}';
  }
  if (p.esperaComprobante) return 'Esperamos tu transferencia';
  if (!p.domicilio) return 'Lo recoges en tienda';
  if (p.fechaEstimada != null) return 'Llega el ${fechaLarga(p.fechaEstimada!, corta: corto)}';
  return p.estado == 'pendiente' ? 'Estamos revisando tu pedido' : 'Va en camino a tu domicilio';
}

String _resumen(Pedido p) => '${p.totalPiezas} ${p.totalPiezas == 1 ? 'pieza' : 'piezas'} · ${formatoPrecioCompleto(p.total)}';

class _PedidoAbierto extends StatelessWidget {
  const _PedidoAbierto({required this.pedido, required this.onTap});
  final Pedido pedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(gradient: AppColors.degradado),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text('Pedido ${pedido.folio}', style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 11.5)),
                      ),
                      ChipEstado(nombreEstado(pedido.estado), tono: TonoEstado.claro),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tituloPedido(pedido, corto: true),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final pieza in pedido.piezas.take(3)) ...[FotoPieza(url: pieza.imagen, tamano: 36, radio: 10), const SizedBox(width: 4)],
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _resumen(pedido),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: LineaTiempo(pasos: pasosDe(pedido)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PedidoCerrado extends StatelessWidget {
  const _PedidoCerrado({required this.pedido, required this.onTap});
  final Pedido pedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fecha = pedido.fechaCreacion;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borde),
        ),
        child: Row(
          children: [
            FotoPieza(url: pedido.piezas.isEmpty ? null : pedido.piezas.first.imagen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pedido ${pedido.folio}', maxLines: 2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    [if (fecha != null) fechaCorta(fecha), formatoPrecioCompleto(pedido.total), ?pedido.metodoPago].join(' · '),
                    style: const TextStyle(color: AppColors.textoSuave, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ChipEstado.pedido(pedido.estado),
          ],
        ),
      ),
    );
  }
}
