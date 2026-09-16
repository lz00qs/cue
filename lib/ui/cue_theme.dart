import 'package:flutter/material.dart';

abstract final class CueColors {
  // Matches the Light and Dark modes of Figma's Cue Color collection.
  static const mode = String.fromEnvironment(
    'CUE_THEME',
    defaultValue: 'light',
  );
  static const isDark = mode == 'dark';

  static const canvas = isDark ? Color(0xFF0B0C10) : Color(0xFFFFFFFF);
  static const sidebar = isDark ? Color(0xFF0B0C10) : Color(0xFFF3F4F7);
  static const card = isDark ? Color(0xFF292B31) : Color(0xFFFFFFFF);
  static const subtle = isDark ? Color(0xFF17181C) : Color(0xFFF8F8FA);
  static const selected = isDark ? Color(0xFF172455) : Color(0xFFE9EEFF);
  static const accent = isDark ? Color(0xFF5B7CFA) : Color(0xFF3A63F3);
  static const primary = isDark ? Color(0xFFFFFFFF) : Color(0xFF17181C);
  static const secondary = isDark ? Color(0xFFD9DBE1) : Color(0xFF5D606B);
  static const tertiary = Color(0xFF8E919B);
  static const onAccent = Color(0xFFFFFFFF);
  static const border = isDark ? Color(0xFF30323A) : Color(0xFFE9EAF0);
  static const strongBorder = isDark ? Color(0xFF5D606B) : Color(0xFFD9DBE1);
  static const danger = isDark ? Color(0xFFFF6B75) : Color(0xFFE45151);
  static const dangerBackground = isDark
      ? Color(0xFF3A171C)
      : Color(0xFFFDECEC);
  static const orange = Color(0xFFD9822B);
  static const orangeBackground = isDark
      ? Color(0xFF3A2814)
      : Color(0xFFFFF1DE);
  static const green = Color(0xFF2F9B63);
  static const greenBackground = isDark ? Color(0xFF123326) : Color(0xFFE5F6EC);
  static const prioritySelected = isDark
      ? Color(0xFF1E2E68)
      : Color(0xFFE9EEFF);
  static const hover = isDark ? Color(0xFF34363D) : Color(0xFFFBFBFD);
  static const sidebarHover = isDark ? Color(0xFF17181C) : Color(0xFFEDEEF2);
}

abstract final class CueTheme {
  static ThemeData get active {
    const brightness = CueColors.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'SF Pro Display',
      scaffoldBackgroundColor: CueColors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CueColors.accent,
        brightness: brightness,
        primary: CueColors.accent,
        onPrimary: CueColors.onAccent,
        surface: CueColors.canvas,
        onSurface: CueColors.primary,
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
        backgroundColor: CueColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: CueColors.card,
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
