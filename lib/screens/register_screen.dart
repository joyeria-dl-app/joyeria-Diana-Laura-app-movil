import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../utils/validaciones.dart';

// Formulario funcional en dos pasos; el diseño visual final (boceto 2) corresponde a la tarea #13.
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
  bool _aceptaAviso = false;
  bool _mostrarErrorAviso = false;
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

  Future<void> _continuar() async {
    final datosValidos = _formDatos.currentState!.validate();
    setState(() => _mostrarErrorAviso = !_aceptaAviso);
    if (!datosValidos || !_aceptaAviso) return;

    final auth = context.read<AuthProvider>();
    try {
      final preguntas = await auth.preguntasSecretas();
      if (!mounted) return;
      setState(() {
        _preguntas = preguntas;
        _paso = 2;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _crearCuenta() async {
    if (!_formPregunta.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.registrarse(
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: _paso == 2 ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _paso = 1)) : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Paso $_paso de 2', textAlign: TextAlign.end),
              const SizedBox(height: 12),
              if (_paso == 1) _pasoDatos() else _pasoPregunta(),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(auth.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('registro_continuar'),
                onPressed: auth.cargando ? null : (_paso == 1 ? _continuar : _crearCuenta),
                child: auth.cargando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_paso == 1 ? 'Continuar' : 'Crear cuenta'),
              ),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                child: const Text('¿Ya tienes cuenta? Inicia sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pasoDatos() {
    return Form(
      key: _formDatos,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('registro_nombre'),
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline_rounded)),
            validator: Validaciones.nombre,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('registro_email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Correo electrónico', prefixIcon: Icon(Icons.alternate_email_rounded)),
            validator: Validaciones.correo,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('registro_password'),
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline_rounded)),
            validator: Validaciones.contrasena,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final r in Validaciones.reglasContrasena(_password.text))
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(r.cumple ? Icons.check : Icons.close, size: 14),
                  const SizedBox(width: 4),
                  Text(r.texto, style: const TextStyle(fontSize: 12)),
                ]),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('registro_confirmacion'),
            controller: _confirmacion,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Confirma tu contraseña', prefixIcon: Icon(Icons.lock_reset_rounded)),
            validator: (v) => Validaciones.confirmacion(v, _password.text),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            key: const Key('registro_aviso'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _aceptaAviso,
            onChanged: (v) => setState(() {
              _aceptaAviso = v ?? false;
              if (_aceptaAviso) _mostrarErrorAviso = false;
            }),
            title: const Text('Acepto el aviso de privacidad'),
            subtitle: _mostrarErrorAviso
                ? Text('Debes aceptar el aviso de privacidad', style: TextStyle(color: Theme.of(context).colorScheme.error))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _pasoPregunta() {
    return Form(
      key: _formPregunta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Elige una pregunta secreta. La usarás si olvidas tu contraseña.'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('registro_tipo_pregunta'),
            initialValue: _tipoPregunta,
            isExpanded: true,
            items: [
              for (var i = 0; i < _preguntas.length; i++)
                DropdownMenuItem(value: '$i', child: Text(_preguntas[i], overflow: TextOverflow.ellipsis)),
              const DropdownMenuItem(value: 'custom', child: Text('Escribir mi propia pregunta')),
            ],
            onChanged: (v) => setState(() => _tipoPregunta = v ?? '0'),
          ),
          if (_tipoPregunta == 'custom') ...[
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('registro_pregunta_personalizada'),
              controller: _preguntaPersonalizada,
              decoration: const InputDecoration(hintText: 'Tu pregunta'),
              validator: Validaciones.preguntaPersonalizada,
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('registro_respuesta'),
            controller: _respuesta,
            decoration: const InputDecoration(hintText: 'Respuesta', prefixIcon: Icon(Icons.key_rounded)),
            validator: Validaciones.respuestaSecreta,
          ),
        ],
      ),
    );
  }
}
