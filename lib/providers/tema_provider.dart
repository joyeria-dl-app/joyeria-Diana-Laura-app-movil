import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../theme/app_theme.dart';

// Los tres temas de los bocetos: el oscuro de siempre, el dorado (#307) y el claro (#212).
enum TemaApp {
  oscuro('Oscuro', Paleta.oscuraBoceto),
  dorado('Dorado', Paleta.doradaBoceto),
  claro('Claro', Paleta.claraBoceto);

  const TemaApp(this.nombre, this.paleta);
  final String nombre;
  final Paleta paleta;

  static TemaApp? desdeTexto(String? valor) {
    for (final t in values) {
      if (t.name == valor) return t;
    }
    return null;
  }
}

// Dónde se guarda en el teléfono el tema que eligió el cliente. No se borra al cerrar sesión:
// es una preferencia del teléfono, no de la cuenta.
abstract class PreferenciaTema {
  Future<TemaApp?> leer();
  Future<void> guardar(TemaApp tema);
}

class SecurePreferenciaTema implements PreferenciaTema {
  SecurePreferenciaTema([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _clave = 'tema';
  // Antes de #307 solo había oscuro o claro y se guardaba como 'true'/'false'.
  static const _claveAnterior = 'tema_oscuro';

  @override
  Future<TemaApp?> leer() async {
    final tema = TemaApp.desdeTexto(await _storage.read(key: _clave));
    if (tema != null) return tema;
    final anterior = await _storage.read(key: _claveAnterior);
    return anterior == null ? null : (anterior == 'true' ? TemaApp.oscuro : TemaApp.claro);
  }

  @override
  Future<void> guardar(TemaApp tema) => _storage.write(key: _clave, value: tema.name);
}

class MemoriaPreferenciaTema implements PreferenciaTema {
  MemoriaPreferenciaTema([this._tema]);
  TemaApp? _tema;

  @override
  Future<TemaApp?> leer() async => _tema;

  @override
  Future<void> guardar(TemaApp tema) async => _tema = tema;
}

// Tema activo de la app. Por defecto, el oscuro.
class TemaProvider extends ChangeNotifier {
  TemaProvider(this._preferencia, {TemaApp inicial = TemaApp.oscuro}) : _actual = inicial {
    _aplicar();
  }

  final PreferenciaTema _preferencia;
  TemaApp _actual;

  TemaApp get actual => _actual;
  // El dorado también es oscuro: la barra de estado y el ThemeData usan el modo oscuro.
  bool get oscuro => _actual.paleta.oscura;
  ThemeData get tema => AppTheme.desde(AppColors.paleta);

  // Se llama antes de abrir la app para que no se vea un instante el tema equivocado. Si el
  // teléfono no deja leer la preferencia, se queda el oscuro.
  static Future<TemaApp> leerInicial(PreferenciaTema preferencia) async {
    try {
      return await preferencia.leer() ?? TemaApp.oscuro;
    } on Object {
      return TemaApp.oscuro;
    }
  }

  Future<void> elegir(TemaApp tema) async {
    if (tema == _actual) return;
    _actual = tema;
    _aplicar();
    notifyListeners();
    try {
      await _preferencia.guardar(tema);
    } on Object {
      // Si no se pudo guardar, el tema cambia igual en esta sesión.
    }
  }

  void _aplicar() {
    AppColors.usar(_actual.paleta);
  }
}

// Los colores se leen de AppColors al construir cada pantalla. Al cambiar el tema se pide
// reconstruir todo lo que ya está en pantalla (también las rutas de atrás), porque muchos
// widgets no dependen de Theme.of y no se enterarían del cambio.
class ReconstruirConTema extends StatefulWidget {
  const ReconstruirConTema({super.key, required this.tema, required this.child});

  final TemaApp tema;
  final Widget child;

  @override
  State<ReconstruirConTema> createState() => _ReconstruirConTemaState();
}

class _ReconstruirConTemaState extends State<ReconstruirConTema> {
  @override
  void didUpdateWidget(ReconstruirConTema anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.tema != widget.tema) {
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
      AnnotatedRegion<SystemUiOverlayStyle>(value: estiloSistema(clara: widget.tema.paleta.oscura), child: widget.child);
}
