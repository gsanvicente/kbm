import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand colors sampled directly from the KBM logo (assets/images/kbm_logo.png)
/// — provisional pending an official Koons brand guide. See
/// docs/adr/0007-custom-design-system-koons-tokens.md.
class KoonsColors {
  KoonsColors._();

  static const navy = Color(0xFF062E56);
  static const blue = Color(0xFF227EA7);
  static const green = Color(0xFF43AB63);

  static const sidebarBackground = navy;
  static const sidebarItemActive = Color(0xFF0E4877);
  static const sidebarText = Color(0xFFC9D6E3);
  static const sidebarTextActive = Colors.white;

  static const surface = Color(0xFFF7F8FA);
  static const border = Color(0xFFE3E6EA);
}

ThemeData buildKbmAdminTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: KoonsColors.blue,
    primary: KoonsColors.blue,
    secondary: KoonsColors.green,
    brightness: Brightness.light,
  );

  final textTheme = GoogleFonts.interTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: KoonsColors.surface,
    textTheme: textTheme,
    dividerColor: KoonsColors.border,
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: KoonsColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: KoonsColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: KoonsColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: KoonsColors.blue, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KoonsColors.blue,
        foregroundColor: Colors.white,
        // Horizontal was missing entirely (defaults to 0) — fine for the
        // full-width login button, but every auto-sized FilledButton
        // (Solicitar, Guardar, Asignar...) had its text touching the
        // pill edges.
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: KoonsColors.navy,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
