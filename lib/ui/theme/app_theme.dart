import 'package:flutter/material.dart';

/// Medieval colour palette and typography for Iron and Stone.
///
/// All constructors are `const` per Constitution Principle IV (performance).
abstract final class AppTheme {
  // ── Palette ────────────────────────────────────────────────────────────────

  /// Deep parchment background — warm off-white.
  static const Color parchment = Color(0xFFF5E6C8);

  /// Dark iron — primary text and borders.
  static const Color ironDark = Color(0xFF2C2C2C);

  /// Stone grey — secondary surfaces and dividers.
  static const Color stone = Color(0xFF8C8C7A);

  /// Blood red — player faction accent (action buttons, HP bars).
  static const Color bloodRed = Color(0xFF8B1A1A);

  /// Midnight blue — AI faction accent.
  static const Color midnightBlue = Color(0xFF1A2B5C);

  /// Forest green — neutral / nature nodes.
  static const Color forestGreen = Color(0xFF2D5A27);

  /// Gold — victory highlights and castle icons.
  static const Color gold = Color(0xFFB8860B);

  // ── Theme ──────────────────────────────────────────────────────────────────

  static ThemeData get themeData => ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: bloodRed,
          onPrimary: parchment,
          secondary: gold,
          onSecondary: ironDark,
          error: bloodRed,
          onError: parchment,
          surface: parchment,
          onSurface: ironDark,
        ),
        scaffoldBackgroundColor: parchment,
        appBarTheme: const AppBarTheme(
          backgroundColor: ironDark,
          foregroundColor: parchment,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'serif',
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: ironDark,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'serif',
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: ironDark,
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            color: ironDark,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: parchment,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: bloodRed,
            foregroundColor: parchment,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
        ),
        dividerColor: stone,
        useMaterial3: true,
      );
}
