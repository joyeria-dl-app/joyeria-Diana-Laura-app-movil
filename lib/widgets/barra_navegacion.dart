import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../providers/carrito_provider.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

enum Seccion { inicio, catalogo, carrito, favoritos, perfil }

// Barra flotante de vidrio de los bocetos de Figma: cada sección con su ícono y su nombre debajo,
// para que se entienda sin adivinar (#318). La activa va en una píldora con degradado.
class BarraNavegacion extends StatelessWidget {
  const BarraNavegacion({super.key, required this.actual});

  final Seccion actual;

  static const _datos = {
    Seccion.inicio: (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    Seccion.catalogo: (Icons.diamond_outlined, Icons.diamond_rounded, 'Catálogo'),
    Seccion.carrito: (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'Carrito'),
    Seccion.favoritos: (Icons.favorite_border_rounded, Icons.favorite_rounded, 'Favoritos'),
    Seccion.perfil: (Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  };

  void _ir(BuildContext context, Seccion destino) {
    if (destino == actual) return;
    switch (destino) {
      case Seccion.inicio:
        Navigator.popUntil(context, (ruta) => ruta.isFirst);
      case Seccion.catalogo:
        Navigator.pushNamed(context, AppRoutes.catalogo);
      case Seccion.carrito:
        Navigator.pushNamed(context, AppRoutes.carrito);
      case Seccion.favoritos:
        Navigator.pushNamed(context, AppRoutes.favoritos);
      case Seccion.perfil:
        Navigator.pushNamed(context, AppRoutes.perfil);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: AppColors.sombra, blurRadius: 40, offset: Offset(0, 20), spreadRadius: -10),
          BoxShadow(color: AppColors.brillo.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: -10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cristal,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.cristalBorde),
            ),
            child: Row(
              children: [
                for (final seccion in Seccion.values)
                  Expanded(
                    child: _Boton(
                      key: Key('nav_${seccion.name}'),
                      seccion: seccion,
                      activa: seccion == actual,
                      // Boceto P5: piezas del carrito en un globo sobre la bolsa.
                      contador: seccion == Seccion.carrito ? context.watch<CarritoProvider?>()?.piezas ?? 0 : 0,
                      onTap: () => _ir(context, seccion),
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

class _Boton extends StatelessWidget {
  const _Boton({super.key, required this.seccion, required this.activa, required this.onTap, this.contador = 0});

  final Seccion seccion;
  final bool activa;
  final VoidCallback onTap;
  final int contador;

  @override
  Widget build(BuildContext context) {
    final (vacio, relleno, nombre) = BarraNavegacion._datos[seccion]!;
    return Semantics(
      button: true,
      selected: activa,
      label: contador > 0 ? '$nombre, $contador piezas' : nombre,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: activa
                  ? LinearGradient(
                      begin: const Alignment(-0.6, -1),
                      end: const Alignment(0.6, 1),
                      colors: [AppColors.primario, AppColors.primario2, AppColors.lila],
                    )
                  : null,
              boxShadow: activa ? [BoxShadow(color: AppColors.brillo.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: -10)] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(activa ? relleno : vacio, size: 22, color: activa ? AppColors.sobreDegradado : AppColors.textoSuave),
                    if (contador > 0) Positioned(top: -6, right: -12, child: _Globo(contador)),
                  ],
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    nombre,
                    maxLines: 1,
                    style: TextStyle(
                      color: activa ? AppColors.sobreDegradado : AppColors.textoSuave,
                      fontSize: 10.5,
                      fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
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

// Globo rosa con el número de piezas (.badge de los bocetos).
class _Globo extends StatelessWidget {
  const _Globo(this.numero);
  final int numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.primario, borderRadius: BorderRadius.circular(9)),
      child: Text(
        numero > 99 ? '99+' : '$numero',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}
