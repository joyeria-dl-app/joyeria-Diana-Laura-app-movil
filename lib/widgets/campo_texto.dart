import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Campo de los bocetos (.inp): 58 px de alto y, al enfocarlo, un halo rosa de 5 px.
class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    required this.controller,
    required this.hint,
    required this.icono,
    this.sufijo,
    this.oculto = false,
    this.teclado,
    this.autofill,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icono;
  final Widget? sufijo;
  final bool oculto;
  final TextInputType? teclado;
  final Iterable<String>? autofill;
  final FormFieldValidator<String>? validator;

  static const double alto = 58;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  bool _enfocado = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // El halo va detrás y solo del alto del campo, para no envolver el texto de error.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: CampoTexto.alto,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: _enfocado ? const [BoxShadow(color: AppColors.suave, spreadRadius: 5)] : const [],
            ),
          ),
        ),
        Focus(
          onFocusChange: (f) => setState(() => _enfocado = f),
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.oculto,
            keyboardType: widget.teclado,
            autofillHints: widget.autofill,
            validator: widget.validator,
            style: const TextStyle(color: AppColors.texto, fontSize: 14),
            decoration: InputDecoration(
              constraints: const BoxConstraints(minHeight: CampoTexto.alto),
              hintText: widget.hint,
              prefixIcon: Icon(widget.icono, size: 21, color: _enfocado ? AppColors.primario : AppColors.textoSuave),
              suffixIcon: widget.sufijo,
            ),
          ),
        ),
      ],
    );
  }
}
