import 'package:flutter/material.dart';

class CuadraTheme {
  CuadraTheme._();

  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color teal700 = Color(0xFF0F766E);
  static const Color emerald700 = Color(0xFF047857);
  static const Color amber700 = Color(0xFFB45309);
  static const Color red700 = Color(0xFFB91C1C);

  static const TextStyle monoAmount = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    fontWeight: FontWeight.w700,
    color: slate900,
  );

  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal700,
        primary: slate900,
        secondary: teal700,
        surface: surface,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: slate200),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: slate900,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: const Color(0xFFCCFBF1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? teal700 : slate600,
          );
        }),
      ),
    );
  }
}
