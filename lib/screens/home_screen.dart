import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../utils/cerrar_sesion.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final usuario = auth.usuario;

    return Scaffold(
      appBar: AppBar(title: const Text('Joyería Diana Laura')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: usuario == null
                ? [
                    const Text('Bienvenido', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.login), child: const Text('Iniciar sesión')),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.register), child: const Text('Crear cuenta')),
                    const SizedBox(height: 12),
                    // El catálogo es público, como "explora sin cuenta" en los bocetos.
                    TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.catalogo), child: const Text('Explorar sin cuenta')),
                  ]
                : [
                    Text('Hola, ${usuario.nombre}', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.catalogo), child: const Text('Ver catálogo')),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.perfil), child: const Text('Mi perfil')),
                    const SizedBox(height: 12),
                    // También se abren desde Mi perfil (HU-14); se quedan aquí porque las pruebas del
                    // emulador (aceptación y entorno) entran por estos botones.
                    OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.misPedidos), child: const Text('Mis pedidos')),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.misApartados), child: const Text('Mis apartados')),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.misPersonalizaciones), child: const Text('Mis personalizaciones')),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => cerrarSesionConConfirmacion(context), child: const Text('Cerrar sesión')),
                  ],
          ),
        ),
      ),
    );
  }
}
