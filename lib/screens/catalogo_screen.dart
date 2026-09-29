import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../services/producto_service.dart';
import '../theme/app_theme.dart';
import '../widgets/barra_navegacion.dart';
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
          const Destellos(),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.primario,
              onRefresh: _recargar,
              child: CustomScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _Encabezado(total: _productos.length, completo: !_hayMas)),
                  ..._contenido(),
                  // Espacio para que la última fila no quede debajo de la barra.
                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            ),
          ),
          const Positioned(left: 16, right: 16, bottom: 16, child: SafeArea(top: false, child: BarraNavegacion(actual: Seccion.catalogo))),
        ],
      ),
    );
  }

  List<Widget> _contenido() {
    // Boceto 4a: tarjetas vacías mientras llega la primera página.
    if (_productos.isEmpty && _cargando) {
      return [_cuadricula(4, (_) => const _TarjetaCargando())];
    }
    // Boceto 4b.
    if (_productos.isEmpty && _error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Aviso(
            icono: Icons.wifi_off_rounded,
            titulo: 'Sin conexión',
            texto: '$_error Revisa tu conexión e intenta de nuevo.',
            onReintentar: _cargarMas,
          ),
        ),
      ];
    }
    // Boceto 4c.
    if (_productos.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Aviso(
            icono: Icons.diamond_outlined,
            titulo: 'Aún no hay piezas',
            texto: 'Pronto agregaremos nuevas joyas. Vuelve más tarde.',
          ),
        ),
      ];
    }
    return [
      _cuadricula(_productos.length, (i) => TarjetaProducto(producto: _productos[i])),
      // Boceto 4d: aviso al pie mientras llega la siguiente página.
      if (_cargando || _error != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: _error != null
                ? Center(child: TextButton(onPressed: _cargarMas, child: const Text('No se pudieron cargar más. Reintentar')))
                : const Column(
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primario, backgroundColor: AppColors.superficie2),
                      ),
                      SizedBox(height: 8),
                      Text('Cargando más piezas…', style: TextStyle(color: AppColors.textoSuave, fontSize: 11.5)),
                    ],
                  ),
          ),
        ),
    ];
  }

  Widget _cuadricula(int total, Widget Function(int) tarjeta) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          mainAxisExtent: TarjetaProducto.alto,
        ),
        itemCount: total,
        itemBuilder: (_, i) => tarjeta(i),
      ),
    );
  }
}

class _TarjetaCargando extends StatelessWidget {
  const _TarjetaCargando();

  @override
  Widget build(BuildContext context) {
    Widget barra(double ancho, double alto) => FractionallySizedBox(
          widthFactor: ancho,
          alignment: Alignment.centerLeft,
          child: Container(
            height: alto,
            decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(alto / 2)),
          ),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF1A0F18),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: ColoredBox(color: Color(0xB3261C22))),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child: Column(children: [barra(0.8, 12), const SizedBox(height: 8), barra(0.4, 14)]),
          ),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.total, required this.completo});
  final int total;
  final bool completo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Antetitulo('Catálogo'),
          const SizedBox(height: 2),
          const TituloDegradado('Nuestras joyas', tamano: 28),
          if (total > 0) ...[
            const SizedBox(height: 16),
            // Mientras falten páginas por cargar no se conoce el total exacto.
            Text(
              completo ? '$total piezas' : '$total+ piezas',
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// Estados 4b y 4c: cuadro rosa suave con ícono, título y botón opcional.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.titulo, required this.texto, this.onReintentar});
  final IconData icono;
  final String titulo;
  final String texto;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(30)),
            child: Icon(icono, size: 40, color: AppColors.primario),
          ),
          const SizedBox(height: 18),
          Text(titulo, style: const TextStyle(color: AppColors.texto, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textoSuave, fontSize: 13)),
          ),
          if (onReintentar != null) ...[
            const SizedBox(height: 22),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.degradado,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Color(0x80CF819F), blurRadius: 30, offset: Offset(0, 16), spreadRadius: -12)],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onReintentar,
                  child: const SizedBox(
                    width: 200,
                    height: 50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Reintentar', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
