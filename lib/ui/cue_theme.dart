import 'package:flutter/material.dart';

abstract final class CueColors {
  static const canvas = Color(0xFFFFFFFF);
  static const sidebar = Color(0xFFF3F4F7);
  static const subtle = Color(0xFFF8F8FA);
  static const selected = Color(0xFFE9EEFF);
  static const accent = Color(0xFF3A63F3);
  static const primary = Color(0xFF17181C);
  static const secondary = Color(0xFF5D606B);
  static const tertiary = Color(0xFF8E919B);
  static const border = Color(0xFFE9EAF0);
  static const danger = Color(0xFFE45151);
  static const dangerBackground = Color(0xFFFDECEC);
  static const orange = Color(0xFFD9822B);
  static const orangeBackground = Color(0xFFFFF1DE);
  static const green = Color(0xFF2F9B63);
}

abstract final class CueTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'SF Pro Display',
      scaffoldBackgroundColor: CueColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CueColors.accent,
        brightness: Brightness.light,
        primary: CueColors.accent,
        surface: CueColors.canvas,
      ),
    );

    return base.copyWith(
      splashFactory: NoSplash.splashFactory,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerColor: CueColors.border,
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
          color: CueColors.primary,
          fontSize: 32,
          height: 38 / 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleMedium: const TextStyle(
          color: CueColors.primary,
          fontSize: 15,
          height: 20 / 15,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: const TextStyle(
          color: CueColors.primary,
          fontSize: 15,
          height: 21 / 15,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: const TextStyle(
          color: CueColors.secondary,
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: const TextStyle(
          color: CueColors.secondary,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: CueColors.canvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: CueColors.canvas,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: CueColors.border),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: CueColors.accent, width: 1.5),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }
}
