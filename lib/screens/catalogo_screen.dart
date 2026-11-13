import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../providers/favoritos_provider.dart';
import '../services/producto_service.dart';
import '../theme/app_theme.dart';
import '../widgets/accion_favorito.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/campo_busqueda.dart';
import '../widgets/decoracion.dart';
import '../widgets/tarjeta_producto.dart';
import 'detalle_screen.dart';
import '../widgets/foto_red.dart';
import '../utils/formato.dart';
import '../utils/fotos.dart';

// Catálogo de piezas (boceto P6). En una categoría o búsqueda muestra páginas numeradas de 6 piezas (#279).
// Desde el Inicio (#244) el catálogo se abre ya filtrado por una categoría o con el buscador listo.
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key, this.categoria, this.buscar = false});

  // Lee lo que le pasa el Inicio al abrir la ruta.
  factory CatalogoScreen.desdeRuta(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return CatalogoScreen(categoria: args is Categoria ? args : null, buscar: args == CatalogoScreen.conBuscador);
  }

  // Argumento de la ruta para abrir el catálogo con el buscador.
  static const conBuscador = 'buscar';

  final Categoria? categoria;
  final bool buscar;

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _scroll = ScrollController();
  // Piezas de la página que se ve; cada página se pide al servidor al elegirla (#279).
  final List<Producto> _productos = [];
  int _pagina = 0;
  // Piezas del filtro en todas las páginas; null si el backend no lo envía.
  int? _total;
  bool _cargando = false;
  String? _error;
  List<Categoria> _categorias = [];
  // Ya respondió la consulta de categorías (con o sin resultado).
  bool _categoriasListas = false;
  Categoria? _categoria;
  final _busqueda = TextEditingController();
  late bool _buscando = widget.buscar;
  // Cambia al elegir otra categoría; así se descartan respuestas de la anterior.
  int _consulta = 0;

  @override
  void initState() {
    super.initState();
    _categoria = widget.categoria;
    _cargarCategorias();
    // Sin filtro se muestran secciones (#254); la cuadrícula solo se pide al filtrar o buscar.
    if (widget.categoria != null || widget.buscar) _cargarPagina(0);
    // Para pintar los corazones; sin sesión se quedan sin marcar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final favoritos = context.read<FavoritosProvider?>();
      if (favoritos != null && !favoritos.cargada) favoritos.cargar();
    });
  }

  // Si fallan, el catálogo se sigue viendo sin la fila de categorías.
  Future<void> _cargarCategorias() async {
    try {
      final categorias = await context.read<ProductoService>().categorias();
      if (mounted) setState(() => _categorias = categorias);
    } on ProductoException {
      // Sin categorías no hay secciones: se muestra la cuadrícula de siempre.
    } finally {
      if (mounted) setState(() => _categoriasListas = true);
      if (mounted && _sinFiltro && _categorias.isEmpty && _productos.isEmpty) _cargarPagina(0);
    }
  }

  bool get _sinFiltro => _categoria == null && _busqueda.text.trim().isEmpty;

  // Catálogo sin filtro (#254): una sección por categoría en lugar de todas las piezas revueltas.
  bool get _porSecciones => _sinFiltro && _categorias.isNotEmpty;

  @override
  void dispose() {
    _scroll.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  int? get _paginas => _total == null ? null : (_total! / ProductoService.porPagina).ceil();

  // Sin el total del backend, se sabe que hay otra página si esta vino llena.
  bool get _haySiguiente => _paginas != null ? _pagina + 1 < _paginas! : _productos.length == ProductoService.porPagina;

  Future<void> _cargarPagina(int pagina) async {
    final consulta = ++_consulta;
    setState(() {
      _cargando = true;
      _error = null;
      _pagina = pagina;
      _productos.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    try {
      final respuesta = await context.read<ProductoService>().pagina(categoriaId: _categoria?.id, busqueda: _busqueda.text, pagina: pagina);
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _productos.addAll(respuesta.piezas);
        _total = respuesta.total;
      });
    } on ProductoException catch (e) {
      if (mounted && consulta == _consulta) setState(() => _error = e.mensaje);
    } finally {
      if (mounted && consulta == _consulta) setState(() => _cargando = false);
    }
  }

  // Si se abrió sin internet, las categorías tampoco llegaron: se piden de nuevo.
  Future<void> _reintentar() async {
    if (_categorias.isEmpty) {
      await _cargarCategorias();
      if (_porSecciones) return;
    }
    await _cargarPagina(_pagina);
  }

  // Primera página de cada categoría, pedida una sola vez: la usan su sección y la pieza destacada,
  // que antes repetían la misma petición y hacían más lenta la primera carga.
  final Map<int, Future<List<Producto>>> _piezasPorCategoria = {};

  Future<List<Producto>> _piezasDe(Categoria categoria) => _piezasPorCategoria.putIfAbsent(categoria.id, () {
    final pedido = context.read<ProductoService>().productos(categoriaId: categoria.id);
    // Si falla se olvida, para que "Reintentar" vuelva a pedirla.
    pedido.catchError((Object _) {
      _piezasPorCategoria.remove(categoria.id);
      return const <Producto>[];
    });
    return pedido;
  });

  Future<void> _recargar() async {
    if (_categorias.isEmpty) _cargarCategorias();
    setState(() {
      _consulta++;
      _piezasPorCategoria.clear();
      _productos.clear();
      _pagina = 0;
      _total = null;
      _cargando = false;
    });
    // En secciones, cambiar _consulta hace que cada sección vuelva a pedir sus piezas.
    if (_porSecciones) return;
    await _cargarPagina(0);
  }

  // Tocar la categoría activa la quita y vuelve a mostrar todas las piezas.
  void _elegir(Categoria categoria) {
    _categoria = categoria.id == _categoria?.id ? null : categoria;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _recargar();
  }

  // Al cerrar el buscador se vuelve a mostrar todo el catálogo.
  void _alternarBuscador() {
    setState(() => _buscando = !_buscando);
    if (!_buscando && _busqueda.text.isNotEmpty) {
      _busqueda.clear();
      _recargar();
    }
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
                      contador: _porSecciones
                          ? '${_categorias.length} categorías'
                          : _productos.isEmpty
                          ? null
                          : _contador(),
                      categorias: _categorias,
                      activa: _categoria,
                      onElegir: _elegir,
                      buscando: _buscando,
                      busqueda: _busqueda,
                      onBuscador: _alternarBuscador,
                      onBuscar: (_) {
                        if (_scroll.hasClients) _scroll.jumpTo(0);
                        _recargar();
                      },
                    ),
                  ),
                  ..._contenido(),
                  // Espacio para que la última fila no quede debajo de la barra.
                  // Espacio para que la paginación quede completa encima de la barra flotante y del
                  // área de gestos del teléfono (#318).
                  SliverToBoxAdapter(child: SizedBox(height: 140 + MediaQuery.paddingOf(context).bottom)),
                ],
              ),
            ),
          ),
          BarraNavegacion.posicionada(context, Seccion.catalogo),
        ],
      ),
    );
  }

  // "21 piezas · página 2 de 4"; sin el total del backend solo se indica la página.
  String _contador() {
    final paginas = _paginas;
    if (paginas != null) return paginas > 1 ? '$_total piezas · página ${_pagina + 1} de $paginas' : '$_total piezas';
    if (_pagina == 0 && !_haySiguiente) return '${_productos.length} piezas';
    return 'Página ${_pagina + 1}';
  }

  List<Widget> _contenido() {
    if (_porSecciones) {
      return [
        SliverToBoxAdapter(child: _Destacada(key: ValueKey('destacada_$_consulta'), piezas: () => _piezasDe(_categorias.first))),
        SliverList.builder(
          itemCount: _categorias.length,
          // Cada sección se construye (y pide sus piezas) al acercarse a la pantalla.
          itemBuilder: (_, i) =>
              _SeccionCategoria(key: ValueKey('seccion_${_categorias[i].id}_$_consulta'), categoria: _categorias[i],
                piezas: () => _piezasDe(_categorias[i]),
                onVerTodo: () => _elegir(_categorias[i]),
              ),
        ),
      ];
    }
    // Mientras llegan las categorías sin filtro todavía no se sabe si habrá secciones.
    if (_sinFiltro && !_categoriasListas) {
      return [_cuadricula(4, (_) => const _TarjetaCargando())];
    }
    // Boceto 4a: tarjetas vacías mientras llega la primera página.
    if (_productos.isEmpty && _cargando) {
      return [_cuadricula(4, (_) => const _TarjetaCargando())];
    }
    // Boceto 4b.
    if (_productos.isEmpty && _error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Aviso(icono: Icons.wifi_off_rounded, titulo: 'Sin conexión', texto: _error!, onReintentar: _reintentar),
        ),
      ];
    }
    // Una página posterior que ya no tiene piezas (cambió el catálogo): se puede volver a las anteriores.
    if (_productos.isEmpty && _pagina > 0) {
      return [
        SliverToBoxAdapter(
          child: _Paginador(pagina: _pagina, paginas: _paginas, haySiguiente: false, onIr: _cargarPagina),
        ),
      ];
    }
    // Boceto 4c.
    if (_productos.isEmpty && _busqueda.text.trim().isNotEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Aviso(
            icono: Icons.search_off_rounded,
            titulo: 'Sin resultados',
            texto: 'No encontramos piezas con "${_busqueda.text.trim()}". Prueba con otra palabra.',
          ),
        ),
      ];
    }
    if (_productos.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _Aviso(icono: Icons.diamond_outlined, titulo: 'Aún no hay piezas', texto: 'Pronto agregaremos nuevas joyas. Vuelve más tarde.'),
        ),
      ];
    }
    return [
      _cuadricula(
        _productos.length,
        (i) => TarjetaProducto(
          producto: _productos[i],
          favorita: context.watch<FavoritosProvider?>()?.esFavorita(_productos[i].id) ?? false,
          onFavorito: () => alternarFavorito(context, _productos[i]),
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DetalleScreen(productoId: _productos[i].id))),
        ),
      ),
      if (_pagina > 0 || _haySiguiente)
        SliverToBoxAdapter(
          child: _Paginador(pagina: _pagina, paginas: _paginas, haySiguiente: _haySiguiente, onIr: _cargarPagina),
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
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: AppColors.superficie2)),
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
    required this.contador,
    required this.categorias,
    required this.activa,
    required this.onElegir,
    required this.buscando,
    required this.busqueda,
    required this.onBuscador,
    required this.onBuscar,
  });
  final String titulo;
  // "5+ piezas" en la cuadrícula o "6 categorías" en secciones; null mientras no hay nada.
  final String? contador;
  final List<Categoria> categorias;
  final Categoria? activa;
  final ValueChanged<Categoria> onElegir;
  final bool buscando;
  final TextEditingController busqueda;
  final VoidCallback onBuscador;
  final ValueChanged<String> onBuscar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [const Antetitulo('Catálogo'), const SizedBox(height: 2), TituloDegradado(titulo, tamano: 28)],
                  ),
                ),
                // Boceto P6: botón de búsqueda a la derecha del título.
                BotonCristal(
                  icono: buscando ? Icons.close_rounded : Icons.search_rounded,
                  descripcion: buscando ? 'Cerrar búsqueda' : 'Buscar',
                  onPressed: onBuscador,
                ),
              ],
            ),
          ),
          if (buscando)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: CampoBusqueda(controlador: busqueda, autofocus: true, onBuscar: onBuscar),
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
                itemBuilder: (_, i) =>
                    _CirculoCategoria(categoria: categorias[i], activa: categorias[i].id == activa?.id, onTap: () => onElegir(categorias[i])),
              ),
            ),
          ],
          if (contador != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              // Mientras falten páginas por cargar no se conoce el total exacto.
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.cristal,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cristalBorde),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.diamond_outlined, size: 14, color: AppColors.primario),
                    const SizedBox(width: 6),
                    Text(
                      contador!,
                      style: TextStyle(color: AppColors.texto, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
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
    // Sin foto: el degradado de la marca en lugar del gris, como "Todo" en el Inicio.
    final sinFoto = DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.degradado),
      child: const Center(child: Icon(Icons.diamond_outlined, size: 26, color: Colors.white)),
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
                  border: Border.all(color: activa ? AppColors.primario : AppColors.cristalBorde, width: 2),
                  boxShadow: activa ? [BoxShadow(color: AppColors.primario.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: -4)] : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: (url == null || url.isEmpty) ? sinFoto : FotoRed(url, error: sinFoto),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                categoria.nombreVisible,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: activa ? FontWeight.w600 : FontWeight.w400, color: activa ? AppColors.texto : AppColors.textoSuave),
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
          Text(
            titulo,
            style: TextStyle(color: AppColors.texto, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
            ),
          ),
          if (onReintentar != null) ...[
            const SizedBox(height: 22),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.degradado,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: AppColors.brillo.withValues(alpha: 0.5), blurRadius: 30, offset: Offset(0, 16), spreadRadius: -12)],
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
                        Text(
                          'Reintentar',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
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

// Sección de una categoría (#254): título, "Ver todo" y una fila con sus primeras piezas. Pide sus
// piezas al construirse, es decir, cuando el usuario llega a ella.
class _SeccionCategoria extends StatefulWidget {
  const _SeccionCategoria({super.key, required this.categoria, required this.piezas, required this.onVerTodo});
  final Categoria categoria;
  final Future<List<Producto>> Function() piezas;
  final VoidCallback onVerTodo;

  static const anchoTarjeta = 170.0;

  @override
  State<_SeccionCategoria> createState() => _SeccionCategoriaState();
}

// Se conserva al salir de la pantalla (#154): sin esto, al subir y bajar la sección se reconstruía
// vacía y volvía a pedir sus piezas al servidor.
class _SeccionCategoriaState extends State<_SeccionCategoria> with AutomaticKeepAliveClientMixin {
  List<Producto>? _piezas;
  bool _error = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = false);
    try {
      // Solo la primera página (6 piezas): el resto se ve con "Ver todo" (#269).
      final piezas = await widget.piezas();
      if (mounted) setState(() => _piezas = piezas);
    } on ProductoException {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final piezas = _piezas;
    // Las categorías sin piezas no se muestran.
    if (piezas != null && piezas.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 6),
            child: Row(
              children: [
                // Barra con el degradado de la marca junto al título de la sección.
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(gradient: AppColors.degradado, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.categoria.nombreVisible,
                        style: TextStyle(color: AppColors.texto, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                      ),
                      if (piezas != null)
                        Text(
                          piezas.length >= 6 ? 'Lo más nuevo' : '${piezas.length} ${piezas.length == 1 ? 'pieza' : 'piezas'}',
                          style: TextStyle(color: AppColors.textoSuave, fontSize: 11.5),
                        ),
                    ],
                  ),
                ),
                TextButton(onPressed: widget.onVerTodo, child: const Text('Ver todo')),
              ],
            ),
          ),
          SizedBox(
            height: TarjetaProducto.alto,
            child: _error
                ? Center(
                    child: TextButton(onPressed: _cargar, child: const Text('No se pudieron cargar. Reintentar')),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: piezas?.length ?? 3,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => SizedBox(
                      width: _SeccionCategoria.anchoTarjeta,
                      child: piezas == null
                          ? const _TarjetaCargando()
                          : TarjetaProducto(
                              producto: piezas[i],
                              favorita: context.watch<FavoritosProvider?>()?.esFavorita(piezas[i].id) ?? false,
                              onFavorito: () => alternarFavorito(context, piezas[i]),
                              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DetalleScreen(productoId: piezas[i].id))),
                            ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Páginas numeradas de la cuadrícula (#279): Anterior, hasta 5 números alrededor de la actual y
// Siguiente. Sin el total del backend solo hay Anterior y Siguiente.
class _Paginador extends StatelessWidget {
  const _Paginador({required this.pagina, required this.paginas, required this.haySiguiente, required this.onIr});
  final int pagina;
  final int? paginas;
  final bool haySiguiente;
  final ValueChanged<int> onIr;

  @override
  Widget build(BuildContext context) {
    final total = paginas;
    final numeros = <int>[];
    if (total != null) {
      final inicio = (pagina - 2).clamp(0, (total - 5).clamp(0, total));
      for (var n = inicio; n < total && numeros.length < 5; n++) {
        numeros.add(n);
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            key: const Key('pagina_anterior'),
            tooltip: 'Página anterior',
            onPressed: pagina > 0 ? () => onIr(pagina - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          for (final n in numeros)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _NumeroPagina(numero: n, activa: n == pagina, onTap: () => onIr(n)),
            ),
          if (total == null) Text('Página ${pagina + 1}', style: TextStyle(color: AppColors.textoSuave, fontSize: 13)),
          IconButton(
            key: const Key('pagina_siguiente'),
            tooltip: 'Página siguiente',
            onPressed: haySiguiente ? () => onIr(pagina + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _NumeroPagina extends StatelessWidget {
  const _NumeroPagina({required this.numero, required this.activa, required this.onTap});
  final int numero;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      label: 'Página ${numero + 1}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('pagina_${numero + 1}'),
        onTap: activa ? null : onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activa ? AppColors.primario : AppColors.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: activa ? AppColors.primario : AppColors.borde),
          ),
          child: Text(
            '${numero + 1}',
            style: TextStyle(color: activa ? Colors.white : AppColors.texto, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// Boceto P5: tarjeta grande con foto, como el banner del Inicio, con la pieza más reciente que
// tenga existencias. Si no hay ninguna disponible no se muestra.
class _Destacada extends StatefulWidget {
  const _Destacada({super.key, required this.piezas});
  final Future<List<Producto>> Function() piezas;

  @override
  State<_Destacada> createState() => _DestacadaState();
}

class _DestacadaState extends State<_Destacada> {
  Producto? _pieza;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final piezas = await widget.piezas();
      final disponibles = piezas.where((p) => !p.agotado).toList();
      if (!mounted || disponibles.isEmpty) return;
      setState(() => _pieza = disponibles.firstWhere((p) => p.esNuevo, orElse: () => disponibles.first));
    } catch (_) {
      // Sin la destacada el catálogo sigue completo.
    }
  }

  @override
  Widget build(BuildContext context) {
    final pieza = _pieza;
    if (pieza == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Semantics(
        button: true,
        label: 'Pieza destacada: ${pieza.nombre}, ${formatoPrecio(pieza.precioFinal)}',
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('catalogo_destacada'),
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DetalleScreen(productoId: pieza.id))),
          child: Container(
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: AppColors.sombra, blurRadius: 40, offset: const Offset(0, 18), spreadRadius: -12)],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (pieza.imagen != null) FotoRed(pieza.imagen!, ancho: anchoFotoGrande) else DecoratedBox(decoration: BoxDecoration(gradient: AppColors.degradado)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [AppColors.primario.withValues(alpha: 0.92), AppColors.lila.withValues(alpha: 0.55), const Color(0x00000000)],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(pieza.esNuevo ? 'Recién llegada' : 'Destacada', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 190,
                        // RichText: el nombre ya aparece en su sección y así no se cuenta dos veces al buscarlo por texto.
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            text: pieza.nombre,
                            style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(formatoPrecio(pieza.precioFinal), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Icon(Icons.arrow_outward_rounded, color: AppColors.primario),
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
