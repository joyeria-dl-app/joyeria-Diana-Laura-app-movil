import 'dart:ui';

import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../theme/app_theme.dart';

enum Seccion { inicio, catalogo, carrito, favoritos, perfil }

// Barra flotante de vidrio de los bocetos (.nav.glass). La sección activa se
// muestra como píldora con degradado, ícono relleno y nombre.
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
        // Se conecta en su historia (HU-14).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Disponible muy pronto')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, 20), spreadRadius: -10),
          BoxShadow(color: Color(0x59CF819F), blurRadius: 18, spreadRadius: -10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x8C281224),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x2EFFAAD7)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [for (final seccion in Seccion.values) _Boton(seccion: seccion, activa: seccion == actual, onTap: () => _ir(context, seccion))],
            ),
          ),
        ),
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({required this.seccion, required this.activa, required this.onTap});

  final Seccion seccion;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (vacio, relleno, nombre) = BarraNavegacion._datos[seccion]!;
    return Semantics(
      button: true,
      selected: activa,
      label: nombre,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: activa
            ? Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment(-0.6, -1),
                    end: Alignment(0.6, 1),
                    colors: [AppColors.primario, AppColors.primario2, AppColors.lila],
                  ),
                  boxShadow: const [BoxShadow(color: Color(0x59CF819F), blurRadius: 18, spreadRadius: -10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(relleno, size: 19, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            : SizedBox(width: 46, height: 46, child: Icon(vacio, size: 24, color: AppColors.textoSuave)),
      ),
    );
  }
}
