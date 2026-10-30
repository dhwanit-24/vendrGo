import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_tokens.dart';

class VendrgoColors {
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryDark = Color(0xFFCC4009);

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

  // Neutrals and semantic colors added for the revamp.
  static const Color splash = Color(0xFFFFF8EA);
  static const Color surfaceMuted = Color(0xFFF6F3F0);
  static const Color divider = Color(0xFFEFEBE7);
  static const Color textTertiary = Color(0xFF9A9A9A);
  static const Color offer = Color(0xFFE23744);
  static const Color successSoft = Color(0xFFE7F8F0);
  static const Color errorSoft = Color(0xFFFFF1EF);
  static const Color warningSoft = Color(0xFFFFF3D8);
}

class VendrgoTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: VendrgoText.fontFamily,
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

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VendrgoColors.primaryDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          backgroundColor: VendrgoColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: VendrgoRadius.mdAll),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      cardTheme: CardThemeData(
        color: VendrgoColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: VendrgoRadius.lgAll,
          side: const BorderSide(color: VendrgoColors.divider),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: VendrgoColors.surface,
        selectedColor: VendrgoColors.peach,
        side: const BorderSide(color: VendrgoColors.border),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: VendrgoColors.text,
        ),
        shape: RoundedRectangleBorder(borderRadius: VendrgoRadius.pillAll),
        showCheckmark: false,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: VendrgoColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: VendrgoColors.peach,
        elevation: 8,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? VendrgoColors.primaryDark
                : VendrgoColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? VendrgoColors.primaryDark
                : VendrgoColors.textSecondary,
          );
        }),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: VendrgoColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(VendrgoRadius.xl),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: VendrgoColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: VendrgoRadius.xlAll),
        titleTextStyle: VendrgoText.heading,
        contentTextStyle: VendrgoText.bodySecondary,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: VendrgoColors.text,
        contentTextStyle: const TextStyle(
          fontFamily: VendrgoText.fontFamily,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: VendrgoRadius.mdAll),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      dividerTheme: const DividerThemeData(
        color: VendrgoColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
