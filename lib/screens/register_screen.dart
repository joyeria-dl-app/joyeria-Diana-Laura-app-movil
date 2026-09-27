import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

// Pantalla provisional: el diseño final corresponde a la tarea #13.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
          child: const Text('¿Ya tienes cuenta? Inicia sesión'),
        ),
      ),
    );
  }
}
