import 'dart:ui';

import 'package:flutter/material.dart';

// Galería del detalle (boceto P7): se desliza de lado y a la derecha muestra
// miniaturas; con más de 3 fotos se ven 2 y un cuadro "+N".
class GaleriaFotos extends StatefulWidget {
  const GaleriaFotos({super.key, required this.imagenes, required this.foto, this.topMiniaturas = 200});

  final List<String> imagenes;
  // Cómo se pinta cada foto grande (la pantalla decide si va en gris).
  final Widget Function(String url) foto;
  final double topMiniaturas;

  @override
  State<GaleriaFotos> createState() => _GaleriaFotosState();
}

class _GaleriaFotosState extends State<GaleriaFotos> {
  final _paginas = PageController();
  int _actual = 0;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _ir(int i) => _paginas.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final total = widget.imagenes.length;
    final visibles = total > 3 ? 2 : total;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _paginas,
          itemCount: total,
          onPageChanged: (i) => setState(() => _actual = i),
          itemBuilder: (_, i) => widget.foto(widget.imagenes[i]),
        ),
        if (total > 1)
          Positioned(
            right: 18,
            top: widget.topMiniaturas,
            child: Column(
              children: [
                for (var i = 0; i < visibles; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Miniatura(url: widget.imagenes[i], activa: i == _actual, descripcion: 'Foto ${i + 1} de $total', onTap: () => _ir(i)),
                  ),
                if (total > visibles)
                  _Mas(
                    restantes: total - visibles,
                    // Si ya se está viendo una de las ocultas, el cuadro se marca.
                    activa: _actual >= visibles,
                    onTap: () => _ir(_actual >= visibles && _actual < total - 1 ? _actual + 1 : visibles),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.url, required this.activa, required this.descripcion, required this.onTap});
  final String url;
  final bool activa;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      label: descripcion,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: activa ? 1 : 0.75,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: activa ? Colors.white : const Color(0x66FFFFFF), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(color: Color(0x73000000)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mas extends StatelessWidget {
  const _Mas({required this.restantes, required this.activa, required this.onTap});
  final int restantes;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ver $restantes fotos más',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x73000000),
                borderRadius: BorderRadius.circular(14),
                border: activa ? Border.all(color: Colors.white, width: 2) : null,
              ),
              child: Text(
                '+$restantes',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
