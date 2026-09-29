import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../services/producto_service.dart';
import '../theme/app_theme.dart';
import '../widgets/decoracion.dart';
import '../widgets/tarjeta_producto.dart';

// Catálogo de piezas (boceto P6). Carga 20 productos y pide más al llegar al final.
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _scroll = ScrollController();
  final List<Producto> _productos = [];
  int _pagina = 0;
  bool _cargando = false;
  bool _hayMas = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _cargarMas();
    });
    _cargarMas();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarMas() async {
    if (_cargando || !_hayMas) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final nuevos = await context.read<ProductoService>().productos(pagina: _pagina);
      if (!mounted) return;
      setState(() {
        _productos.addAll(nuevos);
        _pagina++;
        _hayMas = nuevos.length == ProductoService.porPagina;
      });
    } on ProductoException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _recargar() async {
    setState(() {
      _productos.clear();
      _pagina = 0;
      _hayMas = true;
    });
    await _cargarMas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.primario,
              onRefresh: _recargar,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _Encabezado(total: _productos.length, hayMas: _hayMas)),
                  ..._contenido(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _contenido() {
    if (_productos.isEmpty && _cargando) {
      return const [SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))];
    }
    if (_productos.isEmpty && _error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Aviso(icono: Icons.wifi_off_rounded, texto: _error!, accion: 'Reintentar', onAccion: _cargarMas),
        ),
      ];
    }
    if (_productos.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Aviso(icono: Icons.diamond_outlined, texto: 'Por ahora no hay piezas en el catálogo.'),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.68,
          ),
          itemCount: _productos.length,
          itemBuilder: (_, i) => TarjetaProducto(producto: _productos[i]),
        ),
      ),
      if (_cargando || _error != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Center(
              child: _error != null
                  ? TextButton(onPressed: _cargarMas, child: const Text('No se pudieron cargar más. Reintentar'))
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
    ];
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.total, required this.hayMas});
  final int total;
  final bool hayMas;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context)) ...[
                BotonCristal(
                  icono: Icons.arrow_back_rounded,
                  descripcion: 'Regresar',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 14),
              ],
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CATÁLOGO',
                      style: TextStyle(color: AppColors.textoSuave, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600),
                    ),
                    TituloDegradado('Nuestras joyas'),
                  ],
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Text(
              hayMas ? '$total piezas cargadas' : '$total piezas',
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto, this.accion, this.onAccion});
  final IconData icono;
  final String texto;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 48, color: AppColors.textoSuave),
          const SizedBox(height: 16),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.texto, fontSize: 14)),
          if (accion != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAccion, child: Text(accion!)),
          ],
        ],
      ),
    );
  }
}
