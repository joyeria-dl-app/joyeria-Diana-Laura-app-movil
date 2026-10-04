import 'package:flutter/material.dart';

import '../screens/carrito_screen.dart';
import '../screens/catalogo_screen.dart';
import '../screens/favoritos_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/registro';
  static const String catalogo = '/catalogo';
  static const String carrito = '/carrito';
  static const String favoritos = '/favoritos';

  static Map<String, WidgetBuilder> get routes => {
        home: (_) => const HomeScreen(),
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        catalogo: (_) => const CatalogoScreen(),
        carrito: (_) => const CarritoScreen(),
        favoritos: (_) => const FavoritosScreen(),
      };
}
