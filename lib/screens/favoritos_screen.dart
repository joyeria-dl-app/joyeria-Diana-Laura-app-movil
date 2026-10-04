import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/favoritos_provider.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../widgets/accion_favorito.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/decoracion.dart';
import '../widgets/tarjeta_producto.dart';
import 'detalle_screen.dart';

// Favoritos del cliente (boceto 4b y estados 7a–7e de Bocetos_Sprint2).
class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  @override
  void initState() {
    super.initState();
    // Se piden al abrir para traer lo que el cliente haya guardado en el sitio web.
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<FavoritosProvider>().cargar());
  }

  @override
  Widget build(BuildContext context) {
    final favoritos = context.watch<FavoritosProvider>();
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
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Antetitulo('Tu selección'), SizedBox(height: 2), TituloDegradado('Favoritos', tamano: 28)],
                  ),
                ),
                Expanded(child: _contenido(favoritos)),
              ],
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(top: false, child: BarraNavegacion(actual: Seccion.favoritos)),
          ),
        ],
      ),
    );
  }

  Widget _contenido(FavoritosProvider favoritos) {
    final lista = favoritos.lista;
    // 7b.
    if ((!favoritos.cargada || favoritos.cargando) && lista.isEmpty) return const _Cargando();
    // 7d.
    if (favoritos.sinSesion) {
      return _Aviso(
        icono: Icons.lock_outline_rounded,
        titulo: 'Inicia sesión para ver tus favoritos',
        texto: 'Con tu cuenta, tus favoritos son los mismos que en el sitio web.',
        boton: 'Iniciar sesión',
        iconoBoton: Icons.login_rounded,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
      );
    }
    // 7e.
    if (favoritos.error != null && lista.isEmpty) {
      return _Aviso(
        icono: Icons.wifi_off_rounded,
        titulo: 'Sin conexión',
        texto: 'No se pudieron cargar tus favoritos. Revisa tu conexión e intenta de nuevo.',
        boton: 'Reintentar',
        iconoBoton: Icons.refresh_rounded,
        onPressed: favoritos.cargar,
      );
    }
    // 7c.
    if (lista.isEmpty) {
      return _Aviso(
        icono: Icons.favorite_border_rounded,
        titulo: 'Aún no tienes favoritos',
        texto: 'Toca el corazón de una pieza para guardarla y verla aquí después.',
        boton: 'Ver catálogo',
        iconoBoton: Icons.diamond_outlined,
        onPressed: () => Navigator.pushNamed(context, AppRoutes.catalogo),
      );
    }
    // 7a.
    return RefreshIndicator(
      color: AppColors.primario,
      onRefresh: favoritos.cargar,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                lista.length == 1 ? '1 pieza guardada' : '${lista.length} piezas guardadas',
                style: const TextStyle(color: AppColors.textoSuave, fontSize: 12),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: TarjetaProducto.alto,
              ),
              itemCount: lista.length,
              itemBuilder: (_, i) {
                final pieza = lista[i];
                return TarjetaProducto(
                  key: ValueKey(pieza.id),
                  producto: pieza,
                  favorita: true,
                  onFavorito: () => alternarFavorito(context, pieza, desdeFavoritos: true),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => DetalleScreen(productoId: pieza.id))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.ancho, required this.alto});
  final double ancho;
  final double alto;

  @override
  Widget build(BuildContext context) => Container(
    width: ancho,
    height: alto,
    decoration: BoxDecoration(color: AppColors.superficie2, borderRadius: BorderRadius.circular(alto / 2)),
  );
}

// Boceto 7b: tarjetas vacías mientras llegan los favoritos.
class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Align(alignment: Alignment.centerLeft, child: _Barra(ancho: 110, alto: 12)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              mainAxisExtent: TarjetaProducto.alto,
            ),
            itemCount: 4,
            itemBuilder: (_, _) => Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFF1A0F18),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.borde),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ColoredBox(color: Color(0xB3261C22), child: SizedBox.expand()),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 12, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_Barra(ancho: 100, alto: 12), SizedBox(height: 8), _Barra(ancho: 50, alto: 14)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Estados 7c, 7d y 7e: cuadro rosa suave con ícono, título y botón.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.titulo, required this.texto, required this.boton, required this.iconoBoton, required this.onPressed});
  final IconData icono;
  final String titulo;
  final String texto;
  final String boton;
  final IconData iconoBoton;
  final VoidCallback onPressed;

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
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.texto, fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 250),
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
            ),
          ),
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
                onTap: onPressed,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 210),
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(iconoBoton, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        boton,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
