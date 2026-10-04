import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../widgets/boton_primario.dart';
import '../widgets/campo_texto.dart';
import '../widgets/decoracion.dart';

// La recuperación de contraseña se hace en el sitio web.
final Uri _urlRecuperar = Uri.parse('https://joyeria-diana-laura.vercel.app/olvide');

// Diseño basado en el boceto "1. Inicio de sesión (P2)".
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _ocultar = true;
  bool _correoValido = false;
  bool _recordar = true;

  static final _patronCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AuthProvider>().limpiarError());
    _email.addListener(() {
      final valido = _patronCorreo.hasMatch(_email.text.trim());
      if (valido != _correoValido) setState(() => _correoValido = valido);
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthProvider>().iniciarSesion(_email.text, _password.text, recordar: _recordar);
    if (ok && mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Stack(
        children: [
          const _FotoSuperior(),
          const Destellos(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0x26FFFFFF)),
                          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 12))],
                          image: const DecorationImage(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                    const Text(
                      'JOYERÍA DIANA LAURA',
                      style: TextStyle(color: AppColors.primario, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2),
                    ),
                    const SizedBox(height: 6),
                    const TituloDegradado('Tu brillo,\nen tu bolsillo.'),
                    const SizedBox(height: 18),
                    CampoTexto(
                      key: const Key('login_email'),
                      controller: _email,
                      hint: 'Correo electrónico',
                      icono: Icons.alternate_email_rounded,
                      teclado: TextInputType.emailAddress,
                      autofill: const [AutofillHints.email],
                      sufijo: _correoValido ? const Icon(Icons.check_circle_rounded, color: AppColors.exito, size: 21) : null,
                      validator: (v) => _patronCorreo.hasMatch((v ?? '').trim()) ? null : 'Ingresa un correo válido',
                    ),
                    const SizedBox(height: 12),
                    CampoTexto(
                      key: const Key('login_password'),
                      controller: _password,
                      hint: 'Contraseña',
                      icono: Icons.lock_outline_rounded,
                      oculto: _ocultar,
                      autofill: const [AutofillHints.password],
                      sufijo: IconButton(
                        tooltip: _ocultar ? 'Mostrar contraseña' : 'Ocultar contraseña',
                        icon: Icon(_ocultar ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 21),
                        onPressed: () => setState(() => _ocultar = !_ocultar),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_rounded, size: 16, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(auth.error!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _recordar = !_recordar),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    _recordar ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                                    size: 26,
                                    color: _recordar ? AppColors.primario : AppColors.textoSuave,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Recordarme', style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5)),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => launchUrl(_urlRecuperar, mode: LaunchMode.externalApplication),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                            child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 12.5)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    BotonPrimario(texto: 'Iniciar sesión', cargando: auth.cargando, onPressed: _enviar),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿Nueva por aquí?', style: TextStyle(color: AppColors.textoSuave, fontSize: 13)),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.register),
                          child: const Text('Crea tu cuenta', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false),
                        style: TextButton.styleFrom(foregroundColor: AppColors.textoSuave),
                        child: const Text(
                          'o explora sin cuenta',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FotoSuperior extends StatelessWidget {
  const _FotoSuperior();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login_fondo.jpg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x260B0709), Color(0x330B0709), AppColors.fondo],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
