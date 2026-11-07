import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../theme/app_theme.dart';

// Dónde se guarda en el teléfono si el cliente eligió el tema claro (#212). No se borra al
// cerrar sesión: es una preferencia del teléfono, no de la cuenta.
abstract class PreferenciaTema {
  Future<bool?> leerOscuro();
  Future<void> guardarOscuro(bool oscuro);
}

class SecurePreferenciaTema implements PreferenciaTema {
  SecurePreferenciaTema([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _clave = 'tema_oscuro';

  @override
  Future<bool?> leerOscuro() async {
    final valor = await _storage.read(key: _clave);
    return valor == null ? null : valor == 'true';
  }

  @override
  Future<void> guardarOscuro(bool oscuro) => _storage.write(key: _clave, value: oscuro.toString());
}

class MemoriaPreferenciaTema implements PreferenciaTema {
  MemoriaPreferenciaTema([this._oscuro]);
  bool? _oscuro;

  @override
  Future<bool?> leerOscuro() async => _oscuro;

  @override
  Future<void> guardarOscuro(bool oscuro) async => _oscuro = oscuro;
}

// Tema activo de la app. El oscuro es el de siempre; el claro es la paleta light de los bocetos.
class TemaProvider extends ChangeNotifier {
  TemaProvider(this._preferencia, {this._oscuro = true}) {
    _aplicar();
  }

  final PreferenciaTema _preferencia;
  bool _oscuro;

  bool get oscuro => _oscuro;
  ThemeData get tema => AppTheme.desde(AppColors.paleta);

  // Se llama antes de abrir la app para que no se vea un instante el tema equivocado. Si el
  // teléfono no deja leer la preferencia, se queda el oscuro.
  static Future<bool> leerInicial(PreferenciaTema preferencia) async {
    try {
      return await preferencia.leerOscuro() ?? true;
    } on Object {
      return true;
    }
  }

  Future<void> cambiar({required bool oscuro}) async {
    if (oscuro == _oscuro) return;
    _oscuro = oscuro;
    _aplicar();
    notifyListeners();
    try {
      await _preferencia.guardarOscuro(oscuro);
    } on Object {
      // Si no se pudo guardar, el tema cambia igual en esta sesión.
    }
  }

  void _aplicar() {
    AppColors.usar(_oscuro ? Paleta.oscuraBoceto : Paleta.claraBoceto);
  }
}

// Los colores se leen de AppColors al construir cada pantalla. Al cambiar el tema se pide
// reconstruir todo lo que ya está en pantalla (también las rutas de atrás), porque muchos
// widgets no dependen de Theme.of y no se enterarían del cambio.
class ReconstruirConTema extends StatefulWidget {
  const ReconstruirConTema({super.key, required this.oscuro, required this.child});

  final bool oscuro;
  final Widget child;

  @override
  State<ReconstruirConTema> createState() => _ReconstruirConTemaState();
}

class _ReconstruirConTemaState extends State<ReconstruirConTema> {
  @override
  void didUpdateWidget(ReconstruirConTema anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.oscuro != widget.oscuro) {
      void marcar(Element e) {
        e.markNeedsBuild();
        e.visitChildren(marcar);
      }

      (context as Element).visitChildren(marcar);
    }
  }

  @override
  // Íconos de la barra de estado legibles sobre el fondo de cada tema. Las pantallas con foto o
  // degradado arriba ponen su propio AnnotatedRegion, que tiene prioridad.
  Widget build(BuildContext context) =>
      AnnotatedRegion<SystemUiOverlayStyle>(value: widget.oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark, child: widget.child);
}
