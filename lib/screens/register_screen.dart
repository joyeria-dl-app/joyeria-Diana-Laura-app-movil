import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../utils/validaciones.dart';
import '../widgets/boton_primario.dart';
import '../widgets/campo_texto.dart';
import '../widgets/decoracion.dart';

// Diseño basado en el boceto "2. Registro (P3)". El paso 2 (pregunta secreta)
// sigue el mismo estilo; el sitio web también la pide al registrarse.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formDatos = GlobalKey<FormState>();
  final _formPregunta = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  final _preguntaPersonalizada = TextEditingController();
  final _respuesta = TextEditingController();

  int _paso = 1;
  bool _ocultar = true;
  bool _aceptaAviso = false;
  bool _mostrarErrorAviso = false;
  bool _cargandoPreguntas = false;
  String _tipoPregunta = '0';
  List<String> _preguntas = const [];

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AuthProvider>().limpiarError());
  }

  @override
  void dispose() {
    for (final c in [_nombre, _email, _password, _confirmacion, _preguntaPersonalizada, _respuesta]) {
      c.dispose();
    }
    super.dispose();
  }

  void _regresar() {
    if (_paso == 2) {
      setState(() => _paso = 1);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  Future<void> _continuar() async {
    final datosValidos = _formDatos.currentState!.validate();
    setState(() => _mostrarErrorAviso = !_aceptaAviso);
    if (!datosValidos || !_aceptaAviso) return;

    setState(() => _cargandoPreguntas = true);
    try {
      final preguntas = await context.read<AuthProvider>().preguntasSecretas();
      if (!mounted) return;
      setState(() {
        _preguntas = preguntas;
        _paso = 2;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _cargandoPreguntas = false);
    }
  }

  Future<void> _crearCuenta() async {
    if (!_formPregunta.currentState!.validate()) return;
    final ok = await context.read<AuthProvider>().registrarse(
          nombre: _nombre.text,
          email: _email.text,
          password: _password.text,
          tipoPregunta: _tipoPregunta,
          preguntaPersonalizada: _tipoPregunta == 'custom' ? _preguntaPersonalizada.text : null,
          respuesta: _respuesta.text,
        );
    if (!ok || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.superficie,
        title: const Text('Revisa tu correo'),
        content: Text('Te enviamos un enlace a ${_email.text.trim()} para verificar tu cuenta. '
            'Después de confirmarlo ya puedes iniciar sesión en la app o en el sitio web.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
      ),
    );
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return PopScope(
      canPop: _paso == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _paso = 1);
      },
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: FondoResplandor()),
            const Destellos(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BotonCristal(icono: Icons.arrow_back_rounded, descripcion: 'Regresar', onPressed: _regresar),
                        Etiqueta('Paso $_paso de 2'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (hijo, animacion) => FadeTransition(
                        opacity: animacion,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(animacion),
                          child: hijo,
                        ),
                      ),
                      layoutBuilder: (actual, anteriores) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...anteriores, ?actual],
                      ),
                      child: Column(
                        key: ValueKey(_paso),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Titulo(
                            key: const Key('registro_titulo'),
                            primeraLinea: _paso == 1 ? 'Crea tu' : 'Protege tu',
                            segundaLinea: 'cuenta',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _paso == 1
                                ? 'Guarda favoritos, aparta piezas y sigue tus pedidos.'
                                : 'Si olvidas tu contraseña, te haremos esta pregunta para recuperarla.',
                            style: const TextStyle(color: AppColors.textoSuave, fontSize: 13),
                          ),
                          const SizedBox(height: 22),
                          if (_paso == 1) _pasoDatos() else _pasoPregunta(),
                        ],
                      ),
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 12),
                      _MensajeError(auth.error!),
                    ],
                    const SizedBox(height: 18),
                    BotonPrimario(
                      key: const Key('registro_continuar'),
                      texto: _paso == 1 ? 'Continuar' : 'Crear cuenta',
                      cargando: auth.cargando || _cargandoPreguntas,
                      onPressed: _paso == 1 ? _continuar : _crearCuenta,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('¿Ya tienes cuenta?', style: TextStyle(color: AppColors.textoSuave, fontSize: 13)),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                          child: const Text('Inicia sesión', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pasoDatos() {
    final reglas = Validaciones.reglasContrasena(_password.text);
    // Las 4 barras muestran longitud, mayúscula, minúscula y número.
    final barras = reglas.take(4).toList();
    final cumplidas = _password.text.isEmpty ? 0 : barras.where((r) => r.cumple).length;
    // Como en el boceto, una sola línea con tres reglas; el resto aparece en el error si falta.
    final visibles = [
      ('8 caracteres', reglas[0].cumple),
      ('Mayúscula', reglas[1].cumple),
      ('Número', reglas[3].cumple),
    ];

    return Form(
      key: _formDatos,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoTexto(
            key: const Key('registro_nombre'),
            controller: _nombre,
            hint: 'Nombre completo',
            icono: Icons.person_outline_rounded,
            mayusculas: TextCapitalization.words,
            autofill: const [AutofillHints.name],
            validator: Validaciones.nombre,
          ),
          const SizedBox(height: 12),
          CampoTexto(
            key: const Key('registro_email'),
            controller: _email,
            hint: 'Correo electrónico',
            icono: Icons.alternate_email_rounded,
            teclado: TextInputType.emailAddress,
            autofill: const [AutofillHints.email],
            validator: Validaciones.correo,
          ),
          const SizedBox(height: 12),
          CampoTexto(
            key: const Key('registro_password'),
            controller: _password,
            hint: 'Contraseña',
            icono: Icons.lock_outline_rounded,
            oculto: _ocultar,
            autofill: const [AutofillHints.newPassword],
            sufijo: IconButton(
              tooltip: _ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
              icon: Icon(_ocultar ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 21),
              onPressed: () => setState(() => _ocultar = !_ocultar),
            ),
            validator: Validaciones.contrasena,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < cumplidas ? AppColors.exito : AppColors.superficie2,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final (texto, cumple) in visibles)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cumple ? Icons.check_rounded : Icons.close_rounded,
                          size: 15, color: cumple ? AppColors.exito : AppColors.textoSuave),
                      const SizedBox(width: 3),
                      Text(texto, style: TextStyle(fontSize: 11.5, color: cumple ? AppColors.exito : AppColors.textoSuave)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CampoTexto(
            key: const Key('registro_confirmacion'),
            controller: _confirmacion,
            hint: 'Confirma tu contraseña',
            icono: Icons.lock_reset_rounded,
            oculto: true,
            validator: (v) => Validaciones.confirmacion(v, _password.text),
          ),
          const SizedBox(height: 14),
          CasillaDegradado(
            key: const Key('registro_aviso'),
            valor: _aceptaAviso,
            onChanged: (v) => setState(() {
              _aceptaAviso = v;
              if (v) _mostrarErrorAviso = false;
            }),
            etiqueta: const Text.rich(
              TextSpan(
                text: 'Acepto el ',
                style: TextStyle(color: AppColors.texto, fontSize: 12.5, fontWeight: FontWeight.w500),
                children: [
                  TextSpan(text: 'aviso de privacidad', style: TextStyle(color: AppColors.primario, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          if (_mostrarErrorAviso) const _MensajeError('Debes aceptar el aviso de privacidad'),
        ],
      ),
    );
  }

  Widget _pasoPregunta() {
    final opciones = [
      for (var i = 0; i < _preguntas.length; i++) ('$i', _preguntas[i]),
      ('custom', 'Escribir mi propia pregunta'),
    ];
    return Form(
      key: _formPregunta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (valor, texto) in opciones)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OpcionPregunta(
                key: Key('pregunta_$valor'),
                texto: texto,
                seleccionada: _tipoPregunta == valor,
                onTap: () => setState(() => _tipoPregunta = valor),
              ),
            ),
          if (_tipoPregunta == 'custom') ...[
            const SizedBox(height: 2),
            CampoTexto(
              key: const Key('registro_pregunta_personalizada'),
              controller: _preguntaPersonalizada,
              hint: 'Escribe tu pregunta',
              icono: Icons.help_outline_rounded,
              validator: Validaciones.preguntaPersonalizada,
            ),
          ],
          const SizedBox(height: 12),
          CampoTexto(
            key: const Key('registro_respuesta'),
            controller: _respuesta,
            hint: 'Tu respuesta',
            icono: Icons.key_rounded,
            validator: Validaciones.respuestaSecreta,
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo({super.key, required this.primeraLinea, required this.segundaLinea});
  final String primeraLinea;
  final String segundaLinea;

  @override
  Widget build(BuildContext context) {
    return TituloDegradado('$primeraLinea\n$segundaLinea', adorno: '✦');
  }
}

class _MensajeError extends StatelessWidget {
  const _MensajeError(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_rounded, size: 15, color: AppColors.error),
          const SizedBox(width: 5),
          Expanded(child: Text(texto, style: const TextStyle(color: AppColors.error, fontSize: 11.5))),
        ],
      ),
    );
  }
}

// Tarjeta seleccionable (.opt de los bocetos).
class _OpcionPregunta extends StatelessWidget {
  const _OpcionPregunta({super.key, required this.texto, required this.seleccionada, required this.onTap});
  final String texto;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: seleccionada ? AppColors.primario : AppColors.borde, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: seleccionada
                ? const LinearGradient(colors: [AppColors.suave, Colors.transparent])
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(texto, style: const TextStyle(color: AppColors.texto, fontSize: 13))),
              const SizedBox(width: 10),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: seleccionada ? AppColors.primario : AppColors.textoSuave, width: 2),
                ),
                alignment: Alignment.center,
                child: seleccionada
                    ? Container(width: 11, height: 11, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primario))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
