// Mismas reglas que el formulario de registro del sitio web (RegistroScreen.tsx),
// para que una cuenta creada en la app sea válida también en la web.
class Validaciones {
  static final _soloLetras = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
  static final _correo = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  static final _caracteresPeligrosos = RegExp(r'[<>]');

  static String? nombre(String? valor) {
    final v = valor ?? '';
    if (v.trim().isEmpty) return 'Ingresa tu nombre completo';
    if (v != v.trim()) return 'El nombre no puede empezar ni terminar con espacios';
    if (v.length < 3) return 'El nombre debe tener al menos 3 caracteres';
    if (v.length > 30) return 'El nombre no puede tener más de 30 caracteres';
    if (!_soloLetras.hasMatch(v)) return 'El nombre solo puede tener letras y espacios';
    return null;
  }

  static String? correo(String? valor) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu correo electrónico';
    if (v.length < 6 || v.length > 60 || !_correo.hasMatch(v)) return 'Ingresa un correo válido';
    return null;
  }

  // Reglas de la contraseña en el orden en que se muestran en pantalla.
  static List<ReglaContrasena> reglasContrasena(String valor) => [
    ReglaContrasena('8 a 16 caracteres', valor.length >= 8 && valor.length <= 16),
    ReglaContrasena('Mayúscula', RegExp(r'[A-Z]').hasMatch(valor)),
    ReglaContrasena('Minúscula', RegExp(r'[a-z]').hasMatch(valor)),
    ReglaContrasena('Número', RegExp(r'\d').hasMatch(valor)),
    ReglaContrasena('Sin espacios', valor.isNotEmpty && !valor.contains(' ')),
  ];

  static String? contrasena(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Ingresa una contraseña';
    if (_caracteresPeligrosos.hasMatch(v)) return 'La contraseña contiene caracteres no permitidos';
    final pendiente = reglasContrasena(v).where((r) => !r.cumple).map((r) => r.texto.toLowerCase());
    return pendiente.isEmpty ? null : 'Falta: ${pendiente.join(', ')}';
  }

  static String? confirmacion(String? valor, String contrasena) {
    if ((valor ?? '').isEmpty) return 'Confirma tu contraseña';
    return valor == contrasena ? null : 'Las contraseñas no coinciden';
  }

  static String? preguntaPersonalizada(String? valor) {
    final v = (valor ?? '').trim();
    if (v.length < 5) return 'La pregunta debe tener al menos 5 caracteres';
    if (v.length > 200) return 'La pregunta no puede tener más de 200 caracteres';
    return null;
  }

  static String? respuestaSecreta(String? valor) {
    final v = valor ?? '';
    if (v.trim().isEmpty) return 'Ingresa tu respuesta';
    if (v != v.trim()) return 'La respuesta no puede empezar ni terminar con espacios';
    if (v.length < 2) return 'La respuesta debe tener al menos 2 caracteres';
    if (v.length > 100) return 'La respuesta no puede tener más de 100 caracteres';
    if (_caracteresPeligrosos.hasMatch(v)) return 'La respuesta contiene caracteres no permitidos';
    return null;
  }
}

class ReglaContrasena {
  const ReglaContrasena(this.texto, this.cumple);
  final String texto;
  final bool cumple;
}
