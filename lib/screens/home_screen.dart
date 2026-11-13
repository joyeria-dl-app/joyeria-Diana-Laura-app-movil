import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/banner_inicio.dart';
import '../models/perfil.dart';
import '../models/producto.dart';
import '../providers/auth_provider.dart';
import '../providers/carrito_provider.dart';
import '../providers/favoritos_provider.dart';
import '../providers/inicio_provider.dart';
import '../routes/app_routes.dart';
import '../services/perfil_service.dart';
import '../theme/app_theme.dart';
import '../utils/fotos.dart';
import '../utils/formato.dart';
import '../widgets/accion_favorito.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/campo_busqueda.dart';
import '../widgets/decoracion.dart';
import '../widgets/foto_red.dart';
import '../widgets/tarjeta_producto.dart';
import 'catalogo_screen.dart';
import 'detalle_screen.dart';

// Inicio (boceto P5, #244): saludo, buscador, carrusel de la tienda, categorías y piezas
// destacadas, con la barra de 5 pestañas. Los accesos de la cuenta están en Mi perfil.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (c) => InicioProvider(productos: c.read(), inicio: c.read())..cargar(),
      child: const _Inicio(),
    );
  }
}

class _Inicio extends StatefulWidget {
  const _Inicio();

  @override
  State<_Inicio> createState() => _InicioState();
}

class _InicioState extends State<_Inicio> {
  bool? _conSesion;

  // Con sesión se piden el carrito (para el globo de la barra) y los favoritos (corazones).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final conSesion = context.watch<AuthProvider>().usuario != null;
    if (conSesion == _conSesion) return;
    _conSesion = conSesion;
    if (!conSesion) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CarritoProvider?>()?.cargar();
      final favoritos = context.read<FavoritosProvider?>();
      if (favoritos != null && !favoritos.cargada) favoritos.cargar();
    });
  }

  void _abrirCatalogo({Object? argumento}) => Navigator.pushNamed(context, AppRoutes.catalogo, arguments: argumento);

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuario;
    final inicio = context.watch<InicioProvider>();
    return Scaffold(
      body: Stack(
        children: [
          const FondoResplandor(),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.primario,
              onRefresh: inicio.cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: usuario == null ? const _EncabezadoSinCuenta() : _Saludo(nombre: usuario.nombre),
                  ),
                  const SizedBox(height: 18),
                  // Boceto P5: "Encuentra tu / brillo perfecto" en dos líneas, "brillo" en cursiva rosa.
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _TituloInicio()),
                  // #341: invitación compacta (Iniciar sesión ya está en el encabezado).
                  const SizedBox(height: 14),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: usuario == null ? const _Invitacion() : const _TuCuenta()),
                  const SizedBox(height: 16),
                  // Boceto P5: buscador de vidrio y, a la derecha, el botón degradado de filtros.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: CampoBusqueda(
                            key: const Key('inicio_buscar'),
                            onTap: () => _abrirCatalogo(argumento: CatalogoScreen.conBuscador),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _BotonFiltros(onTap: _abrirCatalogo),
                      ],
                    ),
                  ),
                  ..._contenido(inicio),
                  // #341: la tienda física al final del Inicio.
                  if (!inicio.sinConexion) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _Visitanos(onTap: () => Navigator.pushNamed(context, AppRoutes.zonasEntrega)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          BarraNavegacion.posicionada(context, Seccion.inicio),
        ],
      ),
    );
  }

  // Boceto P5: las tarjetas de Para ti son las mismas del catálogo (P6).
  Widget _pieza(Producto pieza) => TarjetaProducto(
    producto: pieza,
    favorita: context.watch<FavoritosProvider?>()?.esFavorita(pieza.id) ?? false,
    onFavorito: () => alternarFavorito(context, pieza),
    onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DetalleScreen(productoId: pieza.id))),
  );

  List<Widget> _contenido(InicioProvider inicio) {
    if (inicio.cargando && inicio.destacadas.isEmpty && inicio.banners.isEmpty) {
      return const [SizedBox(height: 16), _BannerCargando(), SizedBox(height: 16), _FilaCargando()];
    }
    if (inicio.sinConexion) {
      return [const SizedBox(height: 40), _SinConexion(onReintentar: inicio.cargar)];
    }
    return [
      if (inicio.banners.isNotEmpty) ...[
        const SizedBox(height: 16),
        _Carrusel(banners: inicio.banners, onTap: (b) => b.llevaAUbicacion ? Navigator.pushNamed(context, AppRoutes.zonasEntrega) : _abrirCatalogo()),
      ],
      if (inicio.categorias.isNotEmpty) ...[
        const SizedBox(height: 16),
        // Boceto P5: chips de vidrio; "Todo" con el degradado.
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _Chip(texto: 'Todo', icono: Icons.auto_awesome_rounded, activa: true, onTap: _abrirCatalogo),
              for (final categoria in inicio.categorias) ...[
                const SizedBox(width: 8),
                _Chip(
                  texto: categoria.nombreVisible,
                  onTap: () => _abrirCatalogo(argumento: categoria),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      _Beneficios(onApartar: _abrirCatalogo, onEnvio: () => Navigator.pushNamed(context, AppRoutes.zonasEntrega), onPersonalizar: _abrirCatalogo),
      if (inicio.destacadas.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Para ti',
                  style: TextStyle(color: AppColors.texto, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                ),
              ),
              TextButton(onPressed: _abrirCatalogo, child: const Text('Ver todo')),
            ],
          ),
        ),
        // #341: cuadrícula de 2 columnas (hasta 6 piezas) en lugar de una fila pequeña.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            key: const Key('inicio_para_ti'),
            children: [
              for (var i = 0; i < inicio.destacadas.length && i < 4; i += 2) ...[
                if (i > 0) const SizedBox(height: 14),
                SizedBox(
                  height: TarjetaProducto.alto,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _pieza(inicio.destacadas[i])),
                      const SizedBox(width: 14),
                      Expanded(child: i + 1 < inicio.destacadas.length ? _pieza(inicio.destacadas[i + 1]) : const SizedBox()),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      if (inicio.categorias.isNotEmpty) ...[
        _TituloSeccion('Colecciones', onVerTodo: _abrirCatalogo),
        _Colecciones(
          categorias: inicio.categorias,
          onElegir: (c) => _abrirCatalogo(argumento: c),
        ),
      ],
      const SizedBox(height: 18),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _Personaliza(onTap: _abrirCatalogo),
      ),
    ];
  }
}

// Boceto P5: avatar con la inicial, saludo según la hora y botón de notificaciones.
class _Saludo extends StatelessWidget {
  const _Saludo({required this.nombre});
  final String nombre;

  String get _saludo {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final inicial = nombre.trim().isEmpty ? '✦' : nombre.trim()[0].toUpperCase();
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [AppColors.primario, AppColors.lila]),
          ),
          child: Text(
            inicial,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            key: const Key('inicio_saludo'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_saludo, style: TextStyle(color: AppColors.textoSuave, fontSize: 12)),
              Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.texto, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        // Los avisos del pedido (HU-15) llegan como notificación; aquí se abre su seguimiento.
        BotonCristal(
          key: const Key('inicio_notificaciones'),
          icono: Icons.notifications_outlined,
          descripcion: 'Avisos de mis pedidos',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.misPedidos),
        ),
      ],
    );
  }
}

class _EncabezadoSinCuenta extends StatelessWidget {
  const _EncabezadoSinCuenta();

  @override
  Widget build(BuildContext context) {
    // #341: Iniciar sesión queda arriba y compacto; debajo del título va una invitación compacta.
    return Row(
      children: [
        Expanded(child: Semantics(header: true, child: const Antetitulo('Joyería Diana Laura', tamano: 15))),
        FilledButton(
          key: const Key('inicio_entrar'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Iniciar sesión', maxLines: 1)),
        ),
      ],
    );
  }
}

// Sin sesión: tarjeta protagonista con el degradado de la marca (como "Llega el jueves" de P11).
class _Invitacion extends StatelessWidget {
  const _Invitacion();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('inicio_invitacion'),
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primario, AppColors.lila]),
        boxShadow: [BoxShadow(color: AppColors.primario.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        '✦ Tu cuenta',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Aparta tu pieza con el 50 %',
                      style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '¿Aún no tienes cuenta? Créala para apartar, guardar favoritos y seguir tus pedidos.',
                      style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // En 360 dp (Moto G6) el texto no se parte: relleno corto y letra que se achica si hace falta.
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2B0A19),
                  side: BorderSide.none,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Crear cuenta', maxLines: 1)),
              ),
              const SizedBox(width: 6),
              // El catálogo es público, como "explora sin cuenta" en los bocetos.
              Flexible(
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.catalogo),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Explorar sin cuenta', maxLines: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Con sesión: lo que lleva en la tienda, con el degradado del encabezado de Mi perfil (P15).
class _TuCuenta extends StatefulWidget {
  const _TuCuenta();

  @override
  State<_TuCuenta> createState() => _TuCuentaState();
}

class _TuCuentaState extends State<_TuCuenta> {
  late final Future<ResumenCliente> _resumen = context.read<PerfilService>().resumen();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResumenCliente>(
      future: _resumen,
      builder: (context, foto) {
        final r = foto.data;
        String n(int? v) => foto.connectionState != ConnectionState.done ? '·' : (v?.toString() ?? '–');
        Widget dato(String numero, String texto, String ruta) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pushNamed(context, ruta),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Text(
                    numero,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  Text(texto, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 11.5)),
                ],
              ),
            ),
          ),
        );
        Widget linea() => Container(width: 1, height: 30, color: const Color(0x40FFFFFF));
        return Container(
          key: const Key('inicio_tu_cuenta'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primario, AppColors.lila]),
            boxShadow: [BoxShadow(color: AppColors.primario.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -12)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu resumen',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  dato(n(r?.pedidos), 'Pedidos', AppRoutes.misPedidos),
                  linea(),
                  dato(n(r?.apartados), 'Apartados', AppRoutes.misApartados),
                  linea(),
                  dato(n(r?.favoritos), 'Favoritos', AppRoutes.favoritos),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// #341: la tienda física al final del Inicio.
class _Visitanos extends StatelessWidget {
  const _Visitanos({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('inicio_visitanos'),
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(colors: [AppColors.primario.withValues(alpha: 0.22), AppColors.lila.withValues(alpha: 0.14)]),
            border: Border.all(color: AppColors.cristalBorde),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.cristal, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.storefront_outlined, color: AppColors.primario),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Quieres verla en persona?',
                      style: TextStyle(color: AppColors.texto, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text('Visítanos en la tienda · Cómo llegar', style: TextStyle(color: AppColors.textoSuave, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: AppColors.texto, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Boceto P5: banner de 176 px con la foto, degradado de vino a transparente, título, texto,
// puntos de posición y botón blanco con flecha. Los banners son los del carrusel del sitio web.
class _Carrusel extends StatefulWidget {
  const _Carrusel({required this.banners, required this.onTap});
  final List<BannerInicio> banners;
  final ValueChanged<BannerInicio> onTap;

  @override
  State<_Carrusel> createState() => _CarruselState();
}

class _CarruselState extends State<_Carrusel> {
  final _paginas = PageController(viewportFraction: 0.9);
  int _actual = 0;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 176,
          child: PageView.builder(
            key: const Key('inicio_carrusel'),
            controller: _paginas,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _actual = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _Banner(banner: widget.banners[i], onTap: () => widget.onTap(widget.banners[i])),
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: i == _actual ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(color: i == _actual ? AppColors.primario : AppColors.borde, borderRadius: BorderRadius.circular(3)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.banner, required this.onTap});
  final BannerInicio banner;
  final VoidCallback onTap;

  // Degradado del boceto: rgba(60,8,50,.92) → rgba(120,20,90,.55) → transparente; en el tema
  // Dorado, café oscuro (#307).
  static LinearGradient get _velo => LinearGradient(
    begin: const Alignment(-1, -0.2),
    end: Alignment(1, 0.2),
    colors: [AppColors.velo.withValues(alpha: 0.92), AppColors.velo2.withValues(alpha: 0.55), AppColors.velo2.withValues(alpha: 0)],
    stops: const [0, 0.55, 1],
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: banner.titulo,
      child: Material(
        color: AppColors.superficie2,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FotoRed(
                banner.imagen!,
                ancho: anchoFotoGrande,
                error: ColoredBox(color: AppColors.superficie2),
              ),
              DecoratedBox(decoration: BoxDecoration(gradient: _velo)),
              Positioned(
                left: 20,
                top: 20,
                right: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.1),
                    ),
                    if (banner.descripcion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        banner.descripcion!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.arrow_outward_rounded, size: 20, color: Color(0xFF2B0A19)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Boceto P5: "Encuentra tu" y en la segunda línea "brillo" en cursiva rosa + "perfecto".
class _TituloInicio extends StatelessWidget {
  const _TituloInicio();

  @override
  Widget build(BuildContext context) {
    final base = TituloDegradado.estilo.copyWith(color: AppColors.texto, fontSize: 30);
    return Semantics(
      header: true,
      label: 'Encuentra tu brillo perfecto',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'Encuentra tu\n'),
            TextSpan(
              text: 'brillo',
              // Boceto P5: Playfair Display cursiva en el rosa de la marca.
              style: TextStyle(fontFamily: 'Playfair', fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: AppColors.primario),
            ),
            const TextSpan(text: ' perfecto'),
          ],
        ),
      ),
    );
  }
}

// Boceto P5: botón cuadrado con el degradado a la derecha del buscador; abre el catálogo con sus filtros.
class _BotonFiltros extends StatelessWidget {
  const _BotonFiltros({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Filtros',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('inicio_filtros'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: AppColors.degradado,
              boxShadow: [BoxShadow(color: AppColors.primario.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8), spreadRadius: -6)],
            ),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// Chip de categoría del boceto (.chip y .chip.on).
class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.onTap, this.icono, this.activa = false});
  final String texto;
  final IconData? icono;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activa ? Colors.white : AppColors.texto;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: activa ? AppColors.degradado : null,
            color: activa ? null : AppColors.cristal,
            border: activa ? null : Border.all(color: AppColors.cristalBorde),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[Icon(icono, size: 15, color: color), const SizedBox(width: 6)],
              Text(
                texto,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Inicio más completo: tres servicios reales de la tienda en tarjetas de vidrio.
class _Beneficios extends StatelessWidget {
  const _Beneficios({required this.onApartar, required this.onEnvio, required this.onPersonalizar});
  final VoidCallback onApartar;
  final VoidCallback onEnvio;
  final VoidCallback onPersonalizar;

  @override
  Widget build(BuildContext context) {
    // El alto lo da el contenido: con letra grande (accesibilidad) la tarjeta crece en lugar de cortarse.
    return SingleChildScrollView(
      key: const Key('inicio_beneficios'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Beneficio(icono: Icons.bookmark_added_outlined, titulo: 'Aparta', texto: 'Con el 50 % y paga en abonos', onTap: onApartar),
            const SizedBox(width: 10),
            _Beneficio(icono: Icons.local_shipping_outlined, titulo: 'A domicilio', texto: 'Huejutla y alrededores', onTap: onEnvio),
            const SizedBox(width: 10),
            _Beneficio(icono: Icons.auto_awesome_outlined, titulo: 'Personaliza', texto: 'Grabado y detalles a tu gusto', onTap: onPersonalizar),
          ],
        ),
      ),
    );
  }
}

class _Beneficio extends StatelessWidget {
  const _Beneficio({required this.icono, required this.titulo, required this.texto, required this.onTap});
  final IconData icono;
  final String titulo;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cristal,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cristalBorde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(gradient: AppColors.degradado, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icono, size: 19, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  titulo,
                  style: TextStyle(color: AppColors.texto, fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textoSuave, fontSize: 11, height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Título de sección con "Ver todo" opcional, igual que "Para ti".
class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto, {this.onVerTodo});
  final String texto;
  final VoidCallback? onVerTodo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: AppColors.texto, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4),
            ),
          ),
          if (onVerTodo != null) TextButton(onPressed: onVerTodo, child: const Text('Ver todo')),
        ],
      ),
    );
  }
}

// Colecciones: cada categoría con su foto grande, degradado y nombre encima.
class _Colecciones extends StatelessWidget {
  const _Colecciones({required this.categorias, required this.onElegir});
  final List<Categoria> categorias;
  final ValueChanged<Categoria> onElegir;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        key: const Key('inicio_colecciones'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categorias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final c = categorias[i];
          final sinFoto = DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.degradado),
            child: const Center(child: Icon(Icons.diamond_outlined, color: Colors.white, size: 34)),
          );
          return Semantics(
            button: true,
            label: 'Colección ${c.nombreVisible}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onElegir(c),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 128,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (c.imagen == null || c.imagen!.isEmpty) ? sinFoto : FotoRed(c.imagen!, error: sinFoto),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppColors.velo.withValues(alpha: 0.85)],
                            stops: const [0.45, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // RichText: el nombre ya está en la etiqueta de accesibilidad y no se repite con el chip.
                            RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                text: c.nombreVisible,
                                style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Text('Ver piezas', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Llamada a personalizar: tarjeta con el degradado de la marca.
class _Personaliza extends StatelessWidget {
  const _Personaliza({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('inicio_personaliza'),
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.velo, AppColors.velo2, AppColors.primario.withValues(alpha: 0.9)],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        '✦ Personalizable',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Hazla única',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.6),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pide un grabado o un detalle especial en las piezas personalizables.',
                      style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 12.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.arrow_outward_rounded, color: Color(0xFF2B0A19), size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Boceto P5 ("Para ti"): foto cuadrada, corazón, nombre y precio; en #341 llena su columna de la cuadrícula.
class _PiezaDestacada extends StatelessWidget {
  const _PiezaDestacada({required this.producto, required this.favorita, required this.onFavorito, required this.onTap});
  final Producto producto;
  final bool favorita;
  final VoidCallback onFavorito;
  final VoidCallback onTap;

  static const alto = 118.0 + 64;

  @override
  Widget build(BuildContext context) {
    final sinFoto = ColoredBox(
      color: AppColors.superficie2,
      child: Center(child: Icon(Icons.diamond_outlined, size: 32, color: AppColors.textoSuave)),
    );
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.tarjeta,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: AppColors.borde),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    producto.imagen == null || producto.imagen!.isEmpty ? sinFoto : FotoRed(producto.imagen!, error: sinFoto),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Tooltip(
                        message: favorita ? 'Quitar de favoritos' : 'Agregar a favoritos',
                        child: GestureDetector(
                          onTap: onFavorito,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.cristal,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.cristalBorde),
                            ),
                            child: Icon(
                              favorita ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 17,
                              color: favorita ? AppColors.primario : AppColors.texto,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.texto, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatoPrecio(producto.precioFinal),
                      style: TextStyle(color: AppColors.primario, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerCargando extends StatelessWidget {
  const _BannerCargando();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 176,
        decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(26)),
      ),
    );
  }
}

class _FilaCargando extends StatelessWidget {
  const _FilaCargando();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _PiezaDestacada.alto,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: 150,
          decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(22)),
        ),
      ),
    );
  }
}

class _SinConexion extends StatelessWidget {
  const _SinConexion({required this.onReintentar});
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(30)),
            child: Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.primario),
          ),
          const SizedBox(height: 18),
          Text(
            'Sin conexión',
            style: TextStyle(color: AppColors.texto, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'No se pudo cargar el inicio. Revisa tu conexión e intenta de nuevo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textoSuave, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
