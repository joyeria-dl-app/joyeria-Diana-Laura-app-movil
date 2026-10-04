import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../providers/favoritos_provider.dart';
import '../routes/app_routes.dart';

// Lo que pasa al tocar un corazón (catálogo, detalle o favoritos), con el aviso
// de los bocetos 7f y 7g. Sin sesión invita a iniciarla.
Future<void> alternarFavorito(BuildContext context, Producto producto, {bool desdeFavoritos = false}) async {
  final favoritos = context.read<FavoritosProvider>();
  final avisos = ScaffoldMessenger.of(context);
  final navegador = Navigator.of(context);
  final quedo = await favoritos.alternar(producto);

  final (String texto, String? accion, VoidCallback? alTocar) = switch (quedo) {
    true => (
        'Guardada en tus favoritos',
        desdeFavoritos ? null : 'Ver favoritos',
        () => navegador.pushNamed(AppRoutes.favoritos),
      ),
    false => ('Quitada de tus favoritos', 'Deshacer', () => favoritos.alternar(producto)),
    null when favoritos.sinSesion => (
        'Inicia sesión para guardar tus favoritos',
        'Iniciar sesión',
        () => navegador.pushNamed(AppRoutes.login),
      ),
    null => ('No se pudieron actualizar tus favoritos.', null, null),
  };
  avisos
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(texto),
      action: accion == null ? null : SnackBarAction(label: accion, onPressed: alTocar!),
    ));
}
