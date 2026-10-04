import 'package:flutter/material.dart';

// Paleta del tema oscuro de los bocetos (A3 Interfaces).
class AppColors {
  static const fondo = Color(0xFF0D080C);
  static const superficie = Color(0xFF191116);
  static const superficie2 = Color(0xFF261C22);
  static const borde = Color(0x1AFFBEDC);
  static const primario = Color(0xFFE9AFC7);
  static const primario2 = Color(0xFFCF819F);
  static const lila = Color(0xFFA792C2);
  static const suave = Color(0x29FF8CC6);
  static const texto = Color(0xFFFFF4FA);
  static const textoSuave = Color(0xFFC7A7BB);
  static const exito = Color(0xFF2EBD85);
  static const error = Color(0xFFEF4B5B);

  static const degradado = LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [primario, primario2, lila]);
}

class AppTheme {
  static ThemeData oscuro() {
    const esquinas = BorderRadius.all(Radius.circular(20));
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: AppColors.fondo,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primario,
        secondary: AppColors.primario2,
        tertiary: AppColors.lila,
        surface: AppColors.superficie,
        onSurface: AppColors.texto,
        error: AppColors.error,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, foregroundColor: AppColors.texto, elevation: 0),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.superficie,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: TextStyle(color: AppColors.textoSuave, fontSize: 14),
        prefixIconColor: AppColors.textoSuave,
        suffixIconColor: AppColors.textoSuave,
        border: OutlineInputBorder(
          borderRadius: esquinas,
          borderSide: BorderSide(color: AppColors.borde, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: esquinas,
          borderSide: BorderSide(color: AppColors.borde, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: esquinas,
          borderSide: BorderSide(color: AppColors.primario, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: esquinas,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: esquinas,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: TextStyle(color: AppColors.error, fontSize: 11.5),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primario,
          textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
