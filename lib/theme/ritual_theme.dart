import 'package:flutter/material.dart';

abstract final class RitualColors {
  static const cream = Color(0xFFF6F1E7);
  static const paper = Color(0xFFFFFCF6);
  static const ink = Color(0xFF292620);
  static const sage = Color(0xFF75816E);
  static const terracotta = Color(0xFFC67D62);
  static const honey = Color(0xFFD2A24D);
  static const mist = Color(0xFFE7E2D8);
}

ThemeData ritualTheme() {
  return _ritualTheme(Brightness.light);
}

ThemeData ritualDarkTheme() {
  return _ritualTheme(Brightness.dark);
}

ThemeData _ritualTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xFF25241F) : RitualColors.paper;
  final background = dark ? const Color(0xFF191915) : RitualColors.cream;
  final onSurface = dark ? const Color(0xFFF2ECE1) : RitualColors.ink;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: RitualColors.sage,
        brightness: brightness,
        surface: surface,
      ).copyWith(
        primary: dark ? const Color(0xFFD4DDC9) : RitualColors.ink,
        secondary: RitualColors.terracotta,
        tertiary: RitualColors.honey,
        surface: surface,
        onSurface: onSurface,
        outline: dark ? const Color(0xFF716E64) : const Color(0xFFC9C2B5),
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.4,
        height: 1.05,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.8,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: onSurface,
        height: 1.45,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: onSurface.withValues(alpha: 0.78),
        height: 1.45,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: scheme.outline),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      labelStyle: TextStyle(color: onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: RitualColors.sage, width: 1.4),
      ),
    ),
  );
}
