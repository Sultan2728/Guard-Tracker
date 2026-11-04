import 'package:flutter/material.dart';

/// Onsite visual identity: deep navy surfaces, a teal accent, and clear
/// green / red status colours for "in zone" / "out of zone".
class OnsiteColors {
  static const bg = Color(0xFF0B1220);
  static const surface = Color(0xFF121C2F);
  static const surfaceHigh = Color(0xFF1A2740);
  static const accent = Color(0xFF2DD4BF);
  static const ok = Color(0xFF34D399);
  static const bad = Color(0xFFF87171);
  static const muted = Color(0xFF8A97AD);
}

ThemeData buildOnsiteTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: OnsiteColors.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: OnsiteColors.accent,
    onPrimary: const Color(0xFF04201C),
    surface: OnsiteColors.surface,
    error: OnsiteColors.bad,
  );
  final radius = BorderRadius.circular(16);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: OnsiteColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: OnsiteColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: OnsiteColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: Color(0xFF1F2D47)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OnsiteColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1F2D47)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: OnsiteColors.accent, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xFF2A3B5C)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: OnsiteColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: OnsiteColors.accent,
      foregroundColor: const Color(0xFF04201C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
