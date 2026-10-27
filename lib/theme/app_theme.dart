import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Las dos paletas de los bocetos (A3 Interfaces): la oscura (por defecto) y la clara de
// data-theme="light" (#212). Cada valor es una variable del boceto: --bg, --s1s, --s2, --bd,
// --pri, --pri2, --pri3, --soft, --tx, --mu, --card, --glass, --glassb, --blob1 y --blob2.
class Paleta {
  const Paleta({
    required this.oscura,
    required this.fondo,
    required this.superficie,
    required this.superficie2,
    required this.borde,
    required this.primario,
    required this.primario2,
    required this.lila,
    required this.suave,
    required this.texto,
    required this.textoSuave,
    required this.tarjeta,
    required this.cristal,
    required this.cristalBorde,
    required this.sombra,
    required this.mancha1,
    required this.mancha2,
  });

  final bool oscura;
  final Color fondo;
  final Color superficie;
  final Color superficie2;
  final Color borde;
  final Color primario;
  final Color primario2;
  final Color lila;
  final Color suave;
  final Color texto;
  final Color textoSuave;
  final Color tarjeta;
  final Color cristal;
  final Color cristalBorde;
  final Color sombra;
  final Color mancha1;
  final Color mancha2;

  static const oscuraBoceto = Paleta(
    oscura: true,
    fondo: Color(0xFF0D080C),
    superficie: Color(0xFF191116),
    superficie2: Color(0xFF261C22),
    borde: Color(0x1AFFBEDC),
    primario: Color(0xFFE9AFC7),
    primario2: Color(0xFFCF819F),
    lila: Color(0xFFA792C2),
    suave: Color(0x29FF8CC6),
    texto: Color(0xFFFFF4FA),
    textoSuave: Color(0xFFC7A7BB),
    tarjeta: Color(0xFF1A0F18),
    cristal: Color(0x8C281224),
    cristalBorde: Color(0x2EFFAAD7),
    sombra: Color(0x80000000),
    mancha1: Color(0xFFB8708F),
    mancha2: Color(0xFF6E5A8A),
  );

  static const claraBoceto = Paleta(
    oscura: false,
    fondo: Color(0xFFFFF6FA),
    superficie: Color(0xFFFFFFFF),
    superficie2: Color(0xFFFCE8F1),
    borde: Color(0x24F2458F),
    primario: Color(0xFFC9668F),
    primario2: Color(0xFFB85C83),
    lila: Color(0xFF9486B8),
    suave: Color(0x1FF2458F),
    texto: Color(0xFF2A0F22),
    textoSuave: Color(0xFF8D647C),
    tarjeta: Color(0xFFFFFFFF),
    cristal: Color(0xE6FFFFFF),
    cristalBorde: Color(0xFFF6DCE8),
    sombra: Color(0x40E0307E),
    mancha1: Color(0xFFF4CCDC),
    mancha2: Color(0xFFE2DAEE),
  );
}

// Colores de la paleta activa. Antes eran constantes del tema oscuro; ahora cambian con el
// interruptor de Mi perfil (#212), así que no pueden ir dentro de expresiones const.
class AppColors {
  static Paleta _paleta = Paleta.oscuraBoceto;

  static Paleta get paleta => _paleta;
  static void usar(Paleta paleta) => _paleta = paleta;

  static Color get fondo => _paleta.fondo;
  static Color get superficie => _paleta.superficie;
  static Color get superficie2 => _paleta.superficie2;
  static Color get borde => _paleta.borde;
  static Color get primario => _paleta.primario;
  static Color get primario2 => _paleta.primario2;
  static Color get lila => _paleta.lila;
  static Color get suave => _paleta.suave;
  static Color get texto => _paleta.texto;
  static Color get textoSuave => _paleta.textoSuave;
  // Tarjetas de producto y listas (--card).
  static Color get tarjeta => _paleta.tarjeta;
  // Vidrio de la barra inferior, botones y resúmenes (--glass y --glassb).
  static Color get cristal => _paleta.cristal;
  static Color get cristalBorde => _paleta.cristalBorde;
  static Color get sombra => _paleta.sombra;
  static Color get mancha1 => _paleta.mancha1;
  static Color get mancha2 => _paleta.mancha2;

  // Iguales en los dos temas.
  static const exito = Color(0xFF2EBD85);
  static const error = Color(0xFFEF4B5B);

  static LinearGradient get degradado => LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [primario, primario2, lila]);
}

class AppTheme {
  static ThemeData oscuro() => desde(Paleta.oscuraBoceto);
  static ThemeData claro() => desde(Paleta.claraBoceto);

  static ThemeData desde(Paleta p) {
    const esquinas = BorderRadius.all(Radius.circular(20));
    OutlineInputBorder linea(Color color) => OutlineInputBorder(
      borderRadius: esquinas,
      borderSide: BorderSide(color: color, width: 1.5),
    );
    final colores = p.oscura
        ? ColorScheme.dark(primary: p.primario, secondary: p.primario2, tertiary: p.lila, surface: p.superficie, onSurface: p.texto, error: AppColors.error)
        : ColorScheme.light(
            primary: p.primario,
            onPrimary: Colors.white,
            secondary: p.primario2,
            tertiary: p.lila,
            surface: p.superficie,
            onSurface: p.texto,
            error: AppColors.error,
          );
    return ThemeData(
      useMaterial3: true,
      brightness: p.oscura ? Brightness.dark : Brightness.light,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: p.fondo,
      colorScheme: colores,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.texto,
        elevation: 0,
        systemOverlayStyle: p.oscura ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.superficie,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: TextStyle(color: p.textoSuave, fontSize: 14),
        prefixIconColor: p.textoSuave,
        suffixIconColor: p.textoSuave,
        border: linea(p.borde),
        enabledBorder: linea(p.borde),
        focusedBorder: linea(p.primario),
        errorBorder: linea(AppColors.error),
        focusedErrorBorder: linea(AppColors.error),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 11.5),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primario,
          textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
