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
  static const double desktopSidebarWidth = 68;
  static const double desktopPageGutter = s32;
  static const double desktopPageTop = s32;
  static const double macosSidebarWidth = 76;
  static const double macosTitleBarHeight = s28;
  static const double macosSidebarTop = macosTitleBarHeight + s12;
  static const double macosDesktopPageTop = s24;

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
  static const desktopBoardPage = EdgeInsets.fromLTRB(
    CueSpacing.desktopPageGutter,
    CueSpacing.desktopPageTop,
    0,
    CueSpacing.s24,
  );
  static const desktopScrollablePage = EdgeInsets.fromLTRB(
    CueSpacing.desktopPageGutter,
    CueSpacing.desktopPageTop,
    CueSpacing.desktopPageGutter,
    CueSpacing.s48,
  );
  static const macosDesktopFixedPage = EdgeInsets.fromLTRB(
    CueSpacing.desktopPageGutter,
    CueSpacing.macosDesktopPageTop,
    CueSpacing.desktopPageGutter,
    CueSpacing.s24,
  );
  static const macosDesktopBoardPage = EdgeInsets.fromLTRB(
    CueSpacing.desktopPageGutter,
    CueSpacing.macosDesktopPageTop,
    0,
    CueSpacing.s24,
  );
  static const macosDesktopScrollablePage = EdgeInsets.fromLTRB(
    CueSpacing.desktopPageGutter,
    CueSpacing.macosDesktopPageTop,
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
  static const boardColumn = EdgeInsets.all(CueSpacing.s16);
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
  static Color get boardSurface =>
      isDark ? const Color(0xFF1A1B20) : const Color(0xFFF5F6F8);
  static Color get boardCardBorder =>
      isDark ? const Color(0xFF3A3C44) : const Color(0xFFE1E3E8);
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

/// Shared visual tokens for the priority-quadrant experience.
///
/// Desktop and mobile intentionally use different layout widgets, but their
/// surfaces, borders, type, and spacing come from this single token set.
abstract final class CueQuadrantTokens {
  static const double panelRadius = 16;
  static const double panelGap = CueSpacing.s16;
  static const EdgeInsets panelPadding = EdgeInsets.all(CueSpacing.s16);

  static const double headerToTasksGap = CueSpacing.s12;
  static const double taskGap = CueSpacing.s8;
  static const double taskHeight = 48;
  static const double taskRadius = 10;
  static const EdgeInsets taskPadding = EdgeInsets.symmetric(
    horizontal: CueSpacing.s12,
  );

  static const TextStyle priorityLabelStyle = TextStyle(
    color: CueColors.tertiary,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle taskTitleStyle = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );

  static Color get panelBackground => CueColors.quadrantSurface;
  static Color get panelBorder => CueColors.border;
  static Color get taskBackground => CueColors.card;
  static Color get taskBorder => CueColors.border;
  static Color get taskHoverBackground => CueColors.hover;
  static Color get taskHoverBorder => CueColors.strongBorder;

  static Color accentForPriority(int priority) => switch (priority) {
    0 => CueColors.danger,
    1 => CueColors.orange,
    2 => CueColors.accent,
    _ => CueColors.green,
  };
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
      ).copyWith(
        surfaceTint: Colors.transparent,
        surfaceContainerHigh: CueColors.popover,
        surfaceContainerHighest: CueColors.subtle,
        primaryContainer: CueColors.selected,
        onPrimaryContainer: CueColors.accent,
        outline: CueColors.border,
        outlineVariant: CueColors.border,
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
        fillColor: CueColors.subtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CueSpacing.s14,
          vertical: CueSpacing.s12,
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: CueColors.border),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: CueColors.border),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: CueColors.accent, width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: CueColors.danger),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: CueColors.danger, width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        errorStyle: TextStyle(
          color: CueColors.danger,
          fontSize: 12,
        ),
        labelStyle: TextStyle(
          color: CueColors.secondary,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: CueColors.accent,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          color: CueColors.tertiary,
          fontSize: 13,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: CueColors.popover,
        elevation: 20,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: CueColors.strongBorder),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        hourMinuteColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CueColors.selected;
          }
          return CueColors.subtle;
        }),
        hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CueColors.accent;
          }
          return CueColors.primary;
        }),
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: CueColors.border),
        ),
        hourMinuteTextStyle: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro Display',
        ),
        dialBackgroundColor: CueColors.subtle,
        dialHandColor: CueColors.accent,
        dialTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CueColors.onAccent;
          }
          return CueColors.primary;
        }),
        dialTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'SF Pro Display',
        ),
        entryModeIconColor: CueColors.secondary,
        helpTextStyle: TextStyle(
          color: CueColors.primary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro Display',
        ),
        timeSelectorSeparatorColor: WidgetStateProperty.resolveWith(
          (_) => CueColors.primary,
        ),
        timeSelectorSeparatorTextStyle: WidgetStateProperty.resolveWith(
          (_) => TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w600,
            color: CueColors.primary,
            fontFamily: 'SF Pro Display',
          ),
        ),
        dayPeriodColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CueColors.selected;
          }
          return CueColors.subtle;
        }),
        dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CueColors.accent;
          }
          return CueColors.secondary;
        }),
        dayPeriodBorderSide: BorderSide(color: CueColors.border),
        dayPeriodShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: CueColors.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFamily: 'SF Pro Display',
          ),
        ),
        confirmButtonStyle: TextButton.styleFrom(
          backgroundColor: CueColors.accent,
          foregroundColor: CueColors.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'SF Pro Display',
          ),
        ),
      ),
    );
  }
}
