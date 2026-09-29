import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Manchas de color difuminadas del fondo de los bocetos (.blob).
class FondoResplandor extends StatelessWidget {
  const FondoResplandor({super.key});

  @override
  Widget build(BuildContext context) {
    // Degradado radial en lugar de desenfoque: el blur se veía en anillos en el emulador.
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: -170, right: -180, child: _Mancha(tamano: 440, color: Color(0xFFB8708F))),
          Positioned(bottom: -30, left: -190, child: _Mancha(tamano: 380, color: Color(0xFF6E5A8A))),
        ],
      ),
    );
  }
}

class _Mancha extends StatelessWidget {
  const _Mancha({required this.tamano, required this.color});
  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.12), color.withValues(alpha: 0)],
          stops: const [0, 0.45, 1],
        ),
      ),
    );
  }
}

// Destellos decorativos del fondo de los bocetos (.phone::after).
class Destellos extends StatelessWidget {
  const Destellos({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 70,
      left: 24,
      right: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.14,
          child: Text(
            '✦   ·   ✧        ·\n      ·        ✦    ·\n  ✧      ·            ✦',
            style: TextStyle(color: AppColors.primario, fontSize: 12, height: 46 / 12, letterSpacing: 6),
          ),
        ),
      ),
    );
  }
}

// Título grande con degradado de blanco a rosa (.display de los bocetos).
// Como en el CSS, el degradado abarca todo el ancho disponible y no solo el
// del texto; así casi todo queda blanco y solo el final se vuelve rosa.
class TituloDegradado extends StatelessWidget {
  const TituloDegradado(this.texto, {super.key, this.adorno, this.tamano = 30});

  final String texto;
  // Símbolo al final que conserva el rosa, como la ✦ de "Crea tu cuenta".
  final String? adorno;
  // 30 en registro; el catálogo usa 28.
  final double tamano;

  static const estilo = TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.08);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final pintura = Paint()
          ..shader = const LinearGradient(
            colors: [AppColors.texto, AppColors.texto, AppColors.primario],
            stops: [0, 0.6, 0.95],
          ).createShader(Rect.fromLTWH(0, 0, limites.maxWidth, 70));
        return Text.rich(
          TextSpan(
            style: estilo.copyWith(foreground: pintura, fontSize: tamano),
            children: [
              TextSpan(text: texto),
              if (adorno != null)
                TextSpan(
                  text: ' $adorno',
                  style: TextStyle(foreground: Paint()..color = AppColors.primario, fontWeight: FontWeight.w400),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Texto pequeño en mayúsculas con degradado rosa a lila (.eyebrow), por ejemplo "CATÁLOGO".
class Antetitulo extends StatelessWidget {
  const Antetitulo(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const LinearGradient(colors: [AppColors.primario, AppColors.lila]).createShader(r),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2),
      ),
    );
  }
}

// Botón cuadrado con efecto de vidrio (.gbtn.glass).
class BotonCristal extends StatelessWidget {
  const BotonCristal({super.key, required this.icono, required this.onPressed, required this.descripcion});

  final IconData icono;
  final VoidCallback onPressed;
  final String descripcion;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: descripcion,
      child: Material(
        color: const Color(0x8C281224),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x2EFFAAD7)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icono, size: 20, color: AppColors.texto)),
        ),
      ),
    );
  }
}

// Etiqueta pequeña en rosa (.tag.pri), por ejemplo "Paso 1 de 2".
class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.suave, borderRadius: BorderRadius.circular(20)),
      child: Text(texto, style: const TextStyle(color: AppColors.primario, fontSize: 10.5, fontWeight: FontWeight.w600)),
    );
  }
}

// Casilla de 24 px con degradado cuando está marcada.
class CasillaDegradado extends StatelessWidget {
  const CasillaDegradado({super.key, required this.valor, required this.onChanged, required this.etiqueta});

  final bool valor;
  final ValueChanged<bool> onChanged;
  final Widget etiqueta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: valor,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!valor),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: valor ? const LinearGradient(colors: [AppColors.primario, AppColors.primario2]) : null,
                  border: valor ? null : Border.all(color: AppColors.textoSuave, width: 1.5),
                ),
                child: valor ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: etiqueta),
            ],
          ),
        ),
      ),
    );
  }
}
