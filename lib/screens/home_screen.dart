import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/banner_inicio.dart';
import '../models/producto.dart';
import '../providers/auth_provider.dart';
import '../providers/carrito_provider.dart';
import '../providers/favoritos_provider.dart';
import '../providers/inicio_provider.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../utils/fotos.dart';
import '../utils/formato.dart';
import '../widgets/accion_favorito.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/campo_busqueda.dart';
import '../widgets/decoracion.dart';
import '../widgets/foto_red.dart';
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
                  const SizedBox(height: 14),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: TituloDegradado('Encuentra tu brillo perfecto', tamano: 26)),
                  // #341: invitación compacta (Iniciar sesión ya está en el encabezado).
                  if (usuario == null) ...[const SizedBox(height: 12), const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: _Invitacion())],
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CampoBusqueda(
                      key: const Key('inicio_buscar'),
                      onTap: () => _abrirCatalogo(argumento: CatalogoScreen.conBuscador),
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
          const Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(top: false, child: BarraNavegacion(actual: Seccion.inicio)),
          ),
        ],
      ),
    );
  }

  Widget _pieza(Producto pieza) => _PiezaDestacada(
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
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _Circulo(texto: 'Todo', todo: true, onTap: _abrirCatalogo),
              for (final categoria in inicio.categorias) ...[
                const SizedBox(width: 12),
                _Circulo(
                  texto: categoria.nombreVisible,
                  foto: categoria.imagen,
                  onTap: () => _abrirCatalogo(argumento: categoria),
                ),
              ],
            ],
          ),
        ),
      ],
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
              for (var i = 0; i < inicio.destacadas.length && i < 6; i += 2) ...[
                if (i > 0) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _pieza(inicio.destacadas[i])),
                    const SizedBox(width: 12),
                    Expanded(child: i + 1 < inicio.destacadas.length ? _pieza(inicio.destacadas[i + 1]) : const SizedBox()),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
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
        const Expanded(child: Antetitulo('Joyería Diana Laura')),
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

// #341: invitación compacta de una línea (Iniciar sesión ya está en el encabezado).
class _Invitacion extends StatelessWidget {
  const _Invitacion();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('inicio_invitacion'),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '¿Aún no tienes cuenta? Créala para apartar, guardar favoritos y seguir tus pedidos.',
                  style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5, height: 1.35),
                ),
              ),
              const SizedBox(width: 10),
              // En 360 dp (Moto G6) el texto no se parte: relleno corto y letra que se achica si hace falta.
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Crear cuenta', maxLines: 1)),
              ),
            ],
          ),
          // El catálogo es público, como "explora sin cuenta" en los bocetos.
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.catalogo),
            child: const Text('Explorar sin cuenta'),
          ),
        ],
      ),
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

// #341: categoría en círculo con su foto, como en el catálogo.
class _Circulo extends StatelessWidget {
  const _Circulo({required this.texto, required this.onTap, this.foto, this.todo = false});
  final String texto;
  final String? foto;
  final VoidCallback onTap;
  // "Todo" lleva el degradado; una categoría sin foto, el diamante sobre fondo liso.
  final bool todo;

  @override
  Widget build(BuildContext context) {
    final relleno = DecoratedBox(
      decoration: BoxDecoration(gradient: todo ? AppColors.degradado : null, color: todo ? null : AppColors.superficie2),
      child: Center(child: Icon(todo ? Icons.auto_awesome_rounded : Icons.diamond_outlined, size: 24, color: todo ? Colors.white : AppColors.textoSuave)),
    );
    return Semantics(
      button: true,
      label: texto,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(width: 64, height: 64, child: (foto == null || foto!.isEmpty) ? relleno : FotoRed(foto!, error: relleno)),
              ),
              const SizedBox(height: 6),
              Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: AppColors.texto),
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
