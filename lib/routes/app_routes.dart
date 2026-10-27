import 'package:flutter/material.dart';

import '../screens/carrito_screen.dart';
import '../screens/catalogo_screen.dart';
import '../screens/confirmar_pedido_screen.dart';
import '../screens/favoritos_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/mis_apartados_screen.dart';
import '../screens/mis_pedidos_screen.dart';
import '../screens/mis_personalizaciones_screen.dart';
import '../screens/perfil_screen.dart';
import '../screens/register_screen.dart';
import '../screens/zonas_entrega_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/registro';
  static const String catalogo = '/catalogo';
  static const String carrito = '/carrito';
  static const String favoritos = '/favoritos';
  static const String confirmarPedido = '/confirmar-pedido';
  static const String misPedidos = '/mis-pedidos';
  static const String misApartados = '/mis-apartados';
  static const String misPersonalizaciones = '/mis-personalizaciones';
  static const String perfil = '/perfil';
  static const String zonasEntrega = '/zonas-entrega';

  static Map<String, WidgetBuilder> get routes => {
    home: (_) => const HomeScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    catalogo: (_) => const CatalogoScreen(),
    carrito: (_) => const CarritoScreen(),
    favoritos: (_) => const FavoritosScreen(),
    confirmarPedido: (_) => const ConfirmarPedidoScreen(),
    misPedidos: (_) => const MisPedidosScreen(),
    misApartados: (_) => const MisApartadosScreen(),
    misPersonalizaciones: (_) => const MisPersonalizacionesScreen(),
    perfil: (_) => const PerfilScreen(),
    zonasEntrega: (_) => const ZonasEntregaScreen(),
  };
}
