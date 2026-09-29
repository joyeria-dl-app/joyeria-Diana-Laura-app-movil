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
  List<Categoria> _categorias = [];
  Categoria? _categoria;
  // Cambia al elegir otra categoría; así se descartan respuestas de la anterior.
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _cargarMas();
    });
    _cargarCategorias();
    _cargarMas();
  }

  // Si fallan, el catálogo se sigue viendo sin la fila de categorías.
  Future<void> _cargarCategorias() async {
    try {
      final categorias = await context.read<ProductoService>().categorias();
      if (mounted) setState(() => _categorias = categorias);
    } on ProductoException {
      return;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarMas() async {
    if (_cargando || !_hayMas) return;
    final consulta = _consulta;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final nuevos = await context.read<ProductoService>().productos(categoriaId: _categoria?.id, pagina: _pagina);
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _productos.addAll(nuevos);
        _pagina++;
        _hayMas = nuevos.length == ProductoService.porPagina;
      });
    } on ProductoException catch (e) {
      if (mounted && consulta == _consulta) setState(() => _error = e.mensaje);
    } finally {
      if (mounted && consulta == _consulta) setState(() => _cargando = false);
    }
  }

  Future<void> _recargar() async {
    setState(() {
      _consulta++;
      _productos.clear();
      _pagina = 0;
      _hayMas = true;
      _cargando = false;
    });
    await _cargarMas();
  }

  // Tocar la categoría activa la quita y vuelve a mostrar todas las piezas.
  void _elegir(Categoria categoria) {
    _categoria = categoria.id == _categoria?.id ? null : categoria;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _recargar();
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
                  SliverToBoxAdapter(
                    child: _Encabezado(
                      titulo: _categoria?.nombreVisible ?? 'Nuestras joyas',
                      total: _productos.length,
                      completo: !_hayMas,
                      categorias: _categorias,
                      activa: _categoria,
                      onElegir: _elegir,
                    ),
                  ),
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
            texto: _error!,
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
  const _Encabezado({
    required this.titulo,
    required this.total,
    required this.completo,
    required this.categorias,
    required this.activa,
    required this.onElegir,
  });
  final String titulo;
  final int total;
  final bool completo;
  final List<Categoria> categorias;
  final Categoria? activa;
  final ValueChanged<Categoria> onElegir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Antetitulo('Catálogo'),
                const SizedBox(height: 2),
                TituloDegradado(titulo, tamano: 28),
              ],
            ),
          ),
          if (categorias.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: categorias.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _CirculoCategoria(
                  categoria: categorias[i],
                  activa: categorias[i].id == activa?.id,
                  onTap: () => onElegir(categorias[i]),
                ),
              ),
            ),
          ],
          if (total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              // Mientras falten páginas por cargar no se conoce el total exacto.
              child: Text(
                completo ? '$total piezas' : '$total+ piezas',
                style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// Categoría del boceto P6: foto de 62 px con esquinas de 22 y anillo rosa si está activa.
class _CirculoCategoria extends StatelessWidget {
  const _CirculoCategoria({required this.categoria, required this.activa, required this.onTap});
  final Categoria categoria;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const sinFoto = ColoredBox(
      color: AppColors.superficie2,
      child: Center(child: Icon(Icons.diamond_outlined, size: 26, color: AppColors.textoSuave)),
    );
    final url = categoria.imagen;
    return Semantics(
      button: true,
      selected: activa,
      label: categoria.nombreVisible,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 66,
          child: Column(
            children: [
              Container(
                width: 66,
                height: 66,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: activa ? AppColors.primario : Colors.transparent, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: (url == null || url.isEmpty)
                      ? sinFoto
                      : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => sinFoto),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                categoria.nombreVisible,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
                  color: activa ? AppColors.texto : AppColors.textoSuave,
                ),
              ),
            ],
          ),
        ),
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
