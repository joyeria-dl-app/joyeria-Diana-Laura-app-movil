import 'package:flutter/material.dart';

import '../routes/app_routes.dart';

// Pantalla provisional: el diseño final corresponde a la tarea #9.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.register),
          child: const Text('¿No tienes cuenta? Regístrate'),
        ),
      ),
    );
  }
}
