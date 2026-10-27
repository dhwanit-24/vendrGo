import 'package:flutter/material.dart';

class VendrgoColors {
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryDark = Color(0xFFE95520);

  static const Color accent = Color(0xFF4F46E5);
  static const Color mint = Color(0xFFE7F8F0);
  static const Color peach = Color(0xFFFFEEE7);
  static const Color lavender = Color(0xFFEEEAFE);

  static const Color background = Color(0xFFFFFBF8);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color text = Color(0xFF1F1F1F);
  static const Color textSecondary = Color(0xFF747474);

  static const Color border = Color(0xFFE5E1DD);

  static const Color success = Color(0xFF178B52);
  static const Color error = Color(0xFFD92D20);
  static const Color warning = Color(0xFFB66A00);
}

class VendrgoTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: VendrgoColors.background,

      colorScheme: const ColorScheme.light(
        primary: VendrgoColors.primary,
        secondary: VendrgoColors.accent,
        surface: VendrgoColors.surface,
        error: VendrgoColors.error,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: VendrgoColors.background,
        foregroundColor: VendrgoColors.text,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VendrgoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VendrgoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: VendrgoColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VendrgoColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: VendrgoColors.error, width: 1.5),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          backgroundColor: VendrgoColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: VendrgoColors.text,
          side: const BorderSide(color: VendrgoColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
