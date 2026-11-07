import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Buscador en forma de pastilla de vidrio de los bocetos (.inp.glass, 52 px y esquinas de 18).
// Con [onTap] es solo un acceso (Inicio): no se escribe en él y abre el catálogo con el buscador.
class CampoBusqueda extends StatelessWidget {
  const CampoBusqueda({super.key, this.controlador, this.onBuscar, this.onTap, this.autofocus = false});

  final TextEditingController? controlador;
  final ValueChanged<String>? onBuscar;
  final VoidCallback? onTap;
  final bool autofocus;

  static const _texto = 'Buscar joyas…';

  @override
  Widget build(BuildContext context) {
    final icono = Icon(Icons.search_rounded, size: 20, color: AppColors.textoSuave);
    final contenido = onTap != null
        ? Row(
            children: [
              icono,
              const SizedBox(width: 10),
              Text(_texto, style: TextStyle(color: AppColors.textoSuave, fontSize: 14)),
            ],
          )
        : Row(
            children: [
              icono,
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  key: const Key('catalogo_busqueda'),
                  controller: controlador,
                  autofocus: autofocus,
                  textInputAction: TextInputAction.search,
                  onSubmitted: onBuscar,
                  style: TextStyle(color: AppColors.texto, fontSize: 14),
                  cursorColor: AppColors.primario,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    hintText: _texto,
                    hintStyle: TextStyle(color: AppColors.textoSuave, fontSize: 14),
                  ),
                ),
              ),
            ],
          );
    return Semantics(
      button: onTap != null,
      label: onTap != null ? 'Buscar joyas' : null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: AppColors.cristal,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cristalBorde),
              ),
              child: contenido,
            ),
          ),
        ),
      ),
    );
  }
}
