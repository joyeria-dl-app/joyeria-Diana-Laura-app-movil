import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/perfil.dart';
import '../routes/app_routes.dart';
import '../services/perfil_service.dart';
import '../theme/app_theme.dart';
import '../utils/validaciones.dart';
import '../widgets/boton_primario.dart';
import '../widgets/campo_texto.dart';
import '../widgets/decoracion.dart';

// Ajustes del perfil (HU-14, #213): el engrane de Mi perfil abre esta pantalla para cambiar el
// nombre y el teléfono con las mismas reglas del sitio web. El correo solo se muestra: cambiarlo,
// igual que la contraseña, queda fuera de HU-14. Devuelve true si se guardaron cambios.
class AjustesPerfilScreen extends StatefulWidget {
  const AjustesPerfilScreen({super.key, required this.perfil});

  final Perfil perfil;

  @override
  State<AjustesPerfilScreen> createState() => _AjustesPerfilScreenState();
}

class _AjustesPerfilScreenState extends State<AjustesPerfilScreen> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.perfil.nombre);
  late final _telefono = TextEditingController(text: widget.perfil.telefono ?? '');
  bool _guardando = false;
  // Después del primer intento, cada campo se revisa mientras se escribe y el error se quita al corregirlo.
  AutovalidateMode _revisar = AutovalidateMode.disabled;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      setState(() => _revisar = AutovalidateMode.onUserInteraction);
      return;
    }
    final nombre = _nombre.text;
    final telefono = Validaciones.soloDigitos(_telefono.text);
    final cambioNombre = nombre != widget.perfil.nombre;
    final cambioTelefono = telefono != (widget.perfil.telefono ?? '');
    if (!cambioNombre && !cambioTelefono) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await context.read<PerfilService>().actualizar(nombre: cambioNombre ? nombre : null, telefono: cambioTelefono ? telefono : null);
      if (mounted) Navigator.pop(context, true);
    } on PerfilException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
      if (e.sinSesion) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Inicia sesión para cambiar tus datos'),
              action: SnackBarAction(label: 'Iniciar sesión', onPressed: () => Navigator.pushNamed(context, AppRoutes.login)),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      BotonCristal(icono: Icons.arrow_back_rounded, descripcion: 'Regresar', onPressed: () => Navigator.maybePop(context)),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: 44),
                          child: Text(
                            'Ajustes',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _form,
                    autovalidateMode: _revisar,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                      children: [
                        const Antetitulo('Tus datos'),
                        const SizedBox(height: 10),
                        CampoTexto(
                          key: const Key('ajustes_nombre'),
                          controller: _nombre,
                          hint: 'Nombre completo',
                          icono: Icons.person_outline_rounded,
                          mayusculas: TextCapitalization.words,
                          autofill: const [AutofillHints.name],
                          validator: Validaciones.nombre,
                        ),
                        const SizedBox(height: 12),
                        CampoTexto(
                          key: const Key('ajustes_telefono'),
                          controller: _telefono,
                          hint: 'Teléfono (10 dígitos)',
                          icono: Icons.phone_outlined,
                          teclado: TextInputType.phone,
                          autofill: const [AutofillHints.telephoneNumber],
                          validator: Validaciones.telefono,
                        ),
                        const SizedBox(height: 18),
                        const Antetitulo('Correo'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.superficie,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borde),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.alternate_email_rounded, size: 21, color: AppColors.textoSuave),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  widget.perfil.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: AppColors.textoSuave, fontSize: 14),
                                ),
                              ),
                              Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textoSuave),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('El correo es el de tu cuenta y no se cambia desde aquí.', style: TextStyle(color: AppColors.textoSuave, fontSize: 11.5)),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_rounded, size: 16, color: AppColors.error),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 26),
                        BotonPrimario(key: const Key('ajustes_guardar'), texto: 'Guardar cambios', cargando: _guardando, onPressed: _guardar),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
