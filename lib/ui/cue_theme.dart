import 'package:flutter/material.dart';

/// Cue's spacing scale uses a 4 px base grid. The 2 px half-step is reserved
/// for dense controls and optical alignment inside components.
abstract final class CueSpacing {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s36 = 36;
  static const double s40 = 40;
  static const double s48 = 48;

  static const double mobilePageGutter = s20;
  static const double desktopPageGutter = s32;
  static const double desktopPageTop = s32;

  // Includes the floating mobile navigation bar and its safe breathing room.
  static const double mobileNavigationClearance = 92;
}

/// Semantic insets shared by app-level surfaces.
abstract final class CueInsets {
  static const desktopFixedPage = EdgeInsets.fromLTRB(
    CueSpacing.desktopPageGutter,
    CueSpacing.desktopPageTop,
    CueSpacing.desktopPageGutter,
    CueSpacing.s24,
  );
  static const desktopScrollablePage = EdgeInsets.fromLTRB(
    CueSpacing.desktopPageGutter,
    CueSpacing.desktopPageTop,
    CueSpacing.desktopPageGutter,
    CueSpacing.s48,
  );
  static const mobilePage = EdgeInsets.fromLTRB(
    CueSpacing.mobilePageGutter,
    CueSpacing.s24,
    CueSpacing.mobilePageGutter,
    CueSpacing.mobileNavigationClearance,
  );
  static const mobileForm = EdgeInsets.fromLTRB(
    CueSpacing.mobilePageGutter,
    CueSpacing.s16,
    CueSpacing.mobilePageGutter,
    CueSpacing.s24,
  );
  static const mobileSettingsPage = EdgeInsets.fromLTRB(
    CueSpacing.mobilePageGutter,
    CueSpacing.s24,
    CueSpacing.mobilePageGutter,
    CueSpacing.s36,
  );
  static const mobileSheet = EdgeInsets.fromLTRB(
    CueSpacing.mobilePageGutter,
    CueSpacing.s12,
    CueSpacing.mobilePageGutter,
    CueSpacing.s28,
  );
  static const screen = EdgeInsets.all(CueSpacing.s24);
  static const dialog = screen;
  static const card = EdgeInsets.all(CueSpacing.s12);
}

abstract final class CueColors {
  // Matches the Light and Dark modes of Figma's Cue Color collection.
  static const defaultMode = String.fromEnvironment(
    'CUE_THEME',
    defaultValue: 'system',
  );
  static bool isDark = defaultMode == 'dark';

  static Color get canvas =>
      isDark ? const Color(0xFF0B0C10) : const Color(0xFFFFFFFF);
  static Color get sidebar =>
      isDark ? const Color(0xFF0B0C10) : const Color(0xFFF3F4F7);
  static Color get card =>
      isDark ? const Color(0xFF292B31) : const Color(0xFFFFFFFF);
  static Color get quadrantSurface =>
      isDark ? const Color(0xFF202126) : const Color(0xFFF0F1F5);
  static Color get popover =>
      isDark ? const Color(0xFF383A42) : const Color(0xFFFFFFFF);
  static Color get modalBarrier =>
      isDark ? const Color(0x66000000) : const Color(0x33000000);
  static Color get shadow =>
      isDark ? const Color(0xFF000000) : const Color(0xFF1A1C26);
  static Color get subtle =>
      isDark ? const Color(0xFF17181C) : const Color(0xFFF8F8FA);
  static Color get selected =>
      isDark ? const Color(0xFF172455) : const Color(0xFFE9EEFF);
  static Color get accent =>
      isDark ? const Color(0xFF5B7CFA) : const Color(0xFF3A63F3);
  static Color get primary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF17181C);
  static Color get secondary =>
      isDark ? const Color(0xFFD9DBE1) : const Color(0xFF5D606B);
  static const tertiary = Color(0xFF8E919B);
  static const onAccent = Color(0xFFFFFFFF);
  static Color get border =>
      isDark ? const Color(0xFF30323A) : const Color(0xFFE9EAF0);
  static Color get strongBorder =>
      isDark ? const Color(0xFF5D606B) : const Color(0xFFD9DBE1);
  static Color get danger =>
      isDark ? const Color(0xFFFF6B75) : const Color(0xFFE45151);
  static Color get dangerBackground =>
      isDark ? const Color(0xFF3A171C) : const Color(0xFFFDECEC);
  static const orange = Color(0xFFD9822B);
  static Color get orangeBackground =>
      isDark ? const Color(0xFF3A2814) : const Color(0xFFFFF1DE);
  static const green = Color(0xFF2F9B63);
  static Color get greenBackground =>
      isDark ? const Color(0xFF123326) : const Color(0xFFE5F6EC);
  static Color get prioritySelected =>
      isDark ? const Color(0xFF1E2E68) : const Color(0xFFE9EEFF);
  static Color get hover =>
      isDark ? const Color(0xFF34363D) : const Color(0xFFFBFBFD);
  static Color get sidebarHover =>
      isDark ? const Color(0xFF17181C) : const Color(0xFFEDEEF2);
}

abstract final class CueTheme {
  static ThemeData get active {
    final brightness = CueColors.isDark ? Brightness.dark : Brightness.light;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'SF Pro Display',
      scaffoldBackgroundColor: CueColors.canvas,
      shadowColor: CueColors.shadow,
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
        headlineMedium: TextStyle(
          color: CueColors.primary,
          fontSize: 32,
          height: 38 / 32,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          color: CueColors.primary,
          fontSize: 15,
          height: 20 / 15,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: CueColors.primary,
          fontSize: 15,
          height: 21 / 15,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: CueColors.secondary,
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: CueColors.secondary,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CueColors.card,
        barrierColor: CueColors.modalBarrier,
        shadowColor: CueColors.shadow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        modalBarrierColor: CueColors.modalBarrier,
        shadowColor: CueColors.shadow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CueColors.card,
        contentPadding: EdgeInsets.symmetric(
          horizontal: CueSpacing.s14,
          vertical: CueSpacing.s12,
        ),
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
