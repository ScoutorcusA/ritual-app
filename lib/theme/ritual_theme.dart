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
  final scheme =
      ColorScheme.fromSeed(
        seedColor: RitualColors.sage,
        brightness: Brightness.light,
        surface: RitualColors.paper,
      ).copyWith(
        primary: RitualColors.ink,
        secondary: RitualColors.terracotta,
        tertiary: RitualColors.honey,
        surface: RitualColors.paper,
        onSurface: RitualColors.ink,
        outline: const Color(0xFFC9C2B5),
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RitualColors.cream,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        color: RitualColors.ink,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.4,
        height: 1.05,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: RitualColors.ink,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.8,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: RitualColors.ink,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: RitualColors.ink,
        height: 1.45,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: RitualColors.ink.withValues(alpha: 0.78),
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
    cardTheme: const CardThemeData(
      color: RitualColors.paper,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    chipTheme: base.chipTheme.copyWith(
      side: const BorderSide(color: Color(0xFFD5CEC1)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      labelStyle: const TextStyle(color: RitualColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RitualColors.paper,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: RitualColors.mist),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: RitualColors.sage, width: 1.4),
      ),
    ),
  );
}
