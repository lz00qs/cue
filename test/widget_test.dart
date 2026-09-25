import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cue/data/api_client.dart';
import 'package:cue/data/task_store.dart';
import 'package:cue/data/startup_view_store.dart';
import 'package:cue/data/token_store.dart';
import 'package:cue/l10n/l10n.dart';
import 'package:cue/main.dart';
import 'package:cue/state/app_state.dart';
import 'package:cue/state/page_state.dart';
import 'package:cue/ui/cue_home.dart';
import 'package:cue/ui/cue_theme.dart';
import 'package:cue/ui/cue_widgets.dart';

void main() {
  testWidgets('resizing between desktop and mobile preserves the theme', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    final expectedCanvas = CueColors.isDark
        ? const Color(0xFF0B0C10)
        : const Color(0xFFFFFFFF);
    final expectedAccent = CueColors.isDark
        ? const Color(0xFF5B7CFA)
        : const Color(0xFF3A63F3);
    final expectedBrightness = CueColors.isDark
        ? Brightness.dark
        : Brightness.light;

    void expectTheme() {
      final scaffold = find.byType(Scaffold).first;
      expect(tester.widget<Scaffold>(scaffold).backgroundColor, expectedCanvas);
      final theme = Theme.of(tester.element(scaffold));
      expect(theme.brightness, expectedBrightness);
      expect(theme.colorScheme.primary, expectedAccent);
      expect(theme.dialogTheme.barrierColor, CueColors.modalBarrier);
      expect(theme.bottomSheetTheme.modalBarrierColor, CueColors.modalBarrier);
    }

    expectTheme();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.text('CUE'), findsNothing);
    expectTheme();
  });

  testWidgets('resizing between desktop and mobile preserves selected page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    // Switch to Calendar on desktop
    await tester.tap(find.byKey(const Key('sidebar-calendar')));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);

    // Resize to mobile
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    // Should remain on Calendar page
    expect(find.text('September'), findsWidgets);

    // Switch to Quadrants on mobile
    await tester.tap(find.text('Quadrants'));
    await tester.pumpAndSettle();
    expect(find.textContaining('priority per quadrant'), findsWidgets);

    // Resize back to desktop
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpAndSettle();
    // Should remain on Quadrants view
    expect(find.textContaining('priority per quadrant'), findsWidgets);
  });

  testWidgets('quadrant panels visually separate from task cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-quadrants')));
    await tester.pumpAndSettle();

    final panel = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('quadrant-panel-0')),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = panel.decoration! as BoxDecoration;
    expect(decoration.color, CueColors.quadrantSurface);
    expect(decoration.color, isNot(CueColors.card));
    expect(find.text('All tasks'), findsNothing);
    expect(find.text('Important'), findsNothing);
    expect(find.text('Due soon'), findsNothing);
    expect(find.text('Only P0 is important'), findsNothing);
    expect(find.text('P0 · Important'), findsNothing);
    for (var priority = 0; priority < 4; priority++) {
      final quadrantPanel = find.byKey(ValueKey('quadrant-panel-$priority'));
      expect(
        find.descendant(
          of: quadrantPanel,
          matching: find.byKey(ValueKey('quadrant-priority-$priority')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: quadrantPanel, matching: find.byType(Scrollbar)),
        findsNothing,
      );
    }
    expect(find.byType(CueTaskCard), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('quadrant-task-design-handoff')))
          .height,
      48,
    );
  });

  testWidgets('mobile quadrants use the shared desktop design tokens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quadrants'));
    await tester.pumpAndSettle();

    for (var priority = 0; priority < 4; priority++) {
      final panel = tester.widget<Container>(
        find.byKey(ValueKey('mobile-quadrant-panel-$priority')),
      );
      final decoration = panel.decoration! as BoxDecoration;
      expect(decoration.color, CueQuadrantTokens.panelBackground);
      expect(decoration.border!.top.color, CueQuadrantTokens.panelBorder);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(CueQuadrantTokens.panelRadius),
      );

      final title = tester.widget<Text>(
        find.byKey(ValueKey('mobile-quadrant-title-$priority')),
      );
      expect(title.style!.color, CueQuadrantTokens.accentForPriority(priority));
    }

    final task = tester.widget<Container>(
      find.byKey(const ValueKey('mobile-quadrant-task-design-handoff')),
    );
    final taskDecoration = task.decoration! as BoxDecoration;
    expect(task.constraints!.maxHeight, CueQuadrantTokens.taskHeight);
    expect(taskDecoration.color, CueQuadrantTokens.taskBackground);
    expect(taskDecoration.border!.top.color, CueQuadrantTokens.taskBorder);
    expect(
      taskDecoration.borderRadius,
      BorderRadius.circular(CueQuadrantTokens.taskRadius),
    );
  });

  testWidgets('desktop app views share the canvas background token', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    Color? pageBackground() =>
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor;

    expect(pageBackground(), CueColors.canvas);
    for (final entry in const {
      'Board': 'sidebar-board',
      'Upcoming': 'sidebar-upcoming',
      'List': 'sidebar-list',
      'Calendar': 'sidebar-calendar',
      'Quadrants': 'sidebar-quadrants',
    }.entries) {
      await tester.tap(find.byKey(Key(entry.value)));
      await tester.pumpAndSettle();
      expect(
        pageBackground(),
        CueColors.canvas,
        reason: '${entry.key} background',
      );
    }
  });

  testWidgets('quadrants remain a two-by-two grid in a narrow desktop window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-quadrants')));
    await tester.pumpAndSettle();

    final panels = List.generate(
      4,
      (priority) => find.byKey(ValueKey('quadrant-panel-$priority')),
    );
    final positions = panels.map(tester.getTopLeft).toList();

    expect(positions[0].dy, positions[1].dy);
    expect(positions[0].dx, lessThan(positions[1].dx));
    expect(positions[2].dy, positions[3].dy);
    expect(positions[2].dx, lessThan(positions[3].dx));
    expect(positions[2].dy, greaterThan(positions[0].dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('quadrant tasks can be dragged to another quadrant', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-quadrants')));
    await tester.pumpAndSettle();

    const taskKey = ValueKey('quadrant-task-design-handoff');
    final task = find.byKey(taskKey);
    final sourcePanel = find.byKey(const ValueKey('quadrant-panel-2'));
    final targetPanel = find.byKey(const ValueKey('quadrant-panel-0'));

    expect(find.descendant(of: sourcePanel, matching: task), findsOneWidget);
    expect(find.descendant(of: targetPanel, matching: task), findsNothing);

    await tester.dragFrom(
      tester.getCenter(task),
      tester.getCenter(targetPanel) - tester.getCenter(task),
    );
    await tester.pumpAndSettle();

    expect(find.descendant(of: sourcePanel, matching: task), findsNothing);
    expect(find.descendant(of: targetPanel, matching: task), findsOneWidget);
  });

  testWidgets('appearance can be changed on desktop and mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('appearance-option-dark')));
    await tester.pumpAndSettle();
    expect(CueColors.isDark, isTrue);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      const Color(0xFF0B0C10),
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      const Color(0xFF0B0C10),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('appearance-option-light')));
    await tester.pumpAndSettle();
    expect(CueColors.isDark, isFalse);
    expect(find.text('Light'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.light,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      const Color(0xFFFFFFFF),
    );

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.byKey(const Key('appearance-option-system')));
    await tester.pumpAndSettle();
    expect(find.text('System default'), findsWidgets);
  });

  testWidgets('desktop and mobile expose version and author information', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Cue'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const Key('about-version')), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('lz00qs'), findsOneWidget);
    expect(find.text('lz00qs@gmail.com'), findsOneWidget);

    await tester.tap(find.byKey(const Key('about-close')));
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('mobile-about-cue')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('mobile-about-cue')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('about-version')), findsOneWidget);
    expect(find.text('lz00qs'), findsOneWidget);
    expect(find.text('lz00qs@gmail.com'), findsOneWidget);
  });

  testWidgets('desktop settings change the view used on next launch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    expect(find.textContaining('Focus for today · '), findsOneWidget);
    await tester.tap(find.byKey(const Key('sidebar-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default view'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('default-view-option-today')), findsOneWidget);
    await tester.tap(find.byKey(const Key('default-view-option-calendar')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CueHome)),
      listen: false,
    );
    expect(
      container.read(appControllerProvider).startupView,
      StartupView.calendar,
    );
    expect(find.textContaining('Focus for today · '), findsOneWidget);
  });

  testWidgets('desktop account settings update email and password', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = TaskStore.demo();
    addTearDown(store.dispose);
    String? savedCurrentPassword;
    String? savedEmail;
    String? savedPassword;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: CueTheme.active,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: CueHome(
            userEmail: 'admin@cue.local',
            onUpdateAccount:
                ({required currentPassword, email, newPassword}) async {
                  savedCurrentPassword = currentPassword;
                  savedEmail = email;
                  savedPassword = newPassword;
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Account settings'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const Key('account-email')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('account-email')),
      'new@cue.local',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('account-current-password')),
        matching: find.byType(TextFormField),
      ),
      'CurrentPassword123',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('account-new-password')),
        matching: find.byType(TextFormField),
      ),
      'ReplacementPassword123',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('account-confirm-password')),
        matching: find.byType(TextFormField),
      ),
      'ReplacementPassword123',
    );
    await tester.tap(find.byKey(const Key('account-save')));
    await tester.pumpAndSettle();

    expect(savedCurrentPassword, 'CurrentPassword123');
    expect(savedEmail, 'new@cue.local');
    expect(savedPassword, 'ReplacementPassword123');
    expect(find.text('Account updated'), findsOneWidget);
  });

  testWidgets('mobile exposes account settings as a bottom sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = TaskStore.demo();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: CueTheme.active,
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: CueHome(
            userEmail: 'admin@cue.local',
            onUpdateAccount: ({
              required currentPassword,
              email,
              newPassword,
            }) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Account settings'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Account settings'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('account-email')), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('desktop opens on the configured default view', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = TaskStore.demo();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskStoreProvider.overrideWithValue(store)],
        child: ProviderScope(
          overrides: [
            initialStartupViewProvider.overrideWithValue(StartupView.calendar),
          ],
          child: MaterialApp(
            theme: CueTheme.active,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const CueHome(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-title-picker-trigger')),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CueHome)),
      listen: false,
    );
    expect(container.read(cueHomeUiProvider).view, CueView.calendar);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(
      container.read(mobileUiProvider).destination,
      MobileDestination.calendar,
    );
    expect(find.text('September'), findsWidgets);
  });

  testWidgets(
    'system theme mode responds to system platform brightness changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(
        () => tester.platformDispatcher.clearPlatformBrightnessTestValue(),
      );

      await tester.pumpWidget(const CueApp.demo());
      await tester.pumpAndSettle();

      expect(CueColors.isDark, isFalse);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        const Color(0xFFFFFFFF),
      );

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();

      expect(CueColors.isDark, isTrue);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
        const Color(0xFF0B0C10),
      );
    },
  );

  testWidgets('renders the Cue Today view and switches to Board', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sidebar-today')), findsOneWidget);
    expect(find.textContaining('Focus for today · '), findsOneWidget);
    expect(find.text('Review PCB layout'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sidebar-board')));
    await tester.pumpAndSettle();

    expect(find.text('社会事项'), findsOneWidget);
    expect(find.text('研发事项'), findsOneWidget);
    expect(find.text('工作'), findsOneWidget);
    expect(find.text('未分组'), findsOneWidget);
    expect(find.byKey(const Key('calendar-add-task-button')), findsNothing);
    expect(find.text('Drag cards between groups'), findsNothing);
    final ungroupedListScrollConfiguration = find.descendant(
      of: find.byKey(const Key('group-col-未分组')),
      matching: find.byType(ScrollConfiguration),
    );
    expect(ungroupedListScrollConfiguration, findsOneWidget);

    expect(find.text('Status'), findsNothing);
    expect(find.textContaining('TODO ·'), findsNothing);
    expect(find.textContaining('DOING ·'), findsNothing);
    expect(find.textContaining('DONE ·'), findsNothing);
  });

  testWidgets('desktop sidebar uses a compact fixed icon rail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    final expectedWidth = defaultTargetPlatform == TargetPlatform.macOS
        ? CueSpacing.macosSidebarWidth
        : CueSpacing.desktopSidebarWidth;
    expect(
      tester.getSize(find.byKey(const Key('desktop-sidebar'))).width,
      expectedWidth,
    );
    final sidebarIcons = find.descendant(
      of: find.byKey(const Key('desktop-sidebar')),
      matching: find.byType(Icon),
    );
    expect(
      tester.widgetList<Icon>(sidebarIcons).map((icon) => icon.size),
      everyElement(24),
    );
    expect(find.text('Cue'), findsNothing);
    expect(find.byTooltip('Today'), findsOneWidget);
  });

  testWidgets('desktop sidebar selection changes in the first frame', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    Color? backgroundColor(String key) {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(DecoratedBox),
        ).first,
      );
      return (box.decoration as BoxDecoration).color;
    }

    expect(backgroundColor('sidebar-today'), CueColors.selected);
    await tester.tap(find.byKey(const Key('sidebar-calendar')));
    await tester.pump();

    expect(backgroundColor('sidebar-today'), Colors.transparent);
    expect(backgroundColor('sidebar-calendar'), CueColors.selected);
  });

  testWidgets('macOS sidebar reserves the native traffic-light area', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await tester.pumpWidget(const CueApp.demo());
      await tester.pumpAndSettle();

      final sidebar = tester.widget<Container>(
        find.byKey(const Key('desktop-sidebar')),
      );
      final page = tester.widget<Padding>(
        find.byKey(const Key('desktop-page-padding')),
      );
      expect(
        tester.getSize(find.byKey(const Key('desktop-sidebar'))).width,
        CueSpacing.macosSidebarWidth,
      );
      expect(
        sidebar.padding,
        const EdgeInsets.fromLTRB(
          CueSpacing.s12,
          CueSpacing.macosSidebarTop,
          CueSpacing.s12,
          CueSpacing.s16,
        ),
      );
      expect(page.padding, CueInsets.macosDesktopScrollablePage);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('non-macOS sidebar keeps its original top inset', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await tester.pumpWidget(const CueApp.demo());
      await tester.pumpAndSettle();

      final sidebar = tester.widget<Container>(
        find.byKey(const Key('desktop-sidebar')),
      );
      final page = tester.widget<Padding>(
        find.byKey(const Key('desktop-page-padding')),
      );
      expect(
        tester.getSize(find.byKey(const Key('desktop-sidebar'))).width,
        CueSpacing.desktopSidebarWidth,
      );
      expect(sidebar.padding, const EdgeInsets.fromLTRB(12, 12, 12, 16));
      expect(page.padding, CueInsets.desktopScrollablePage);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('macOS compact layout stays below the traffic lights', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    try {
      await tester.pumpWidget(const CueApp.demo());
      await tester.pumpAndSettle();

      final safeArea = tester.widget<Padding>(
        find.byKey(const Key('macos-titlebar-safe-area')),
      );
      expect(
        safeArea.padding,
        const EdgeInsets.only(top: CueSpacing.macosTitleBarHeight),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('manual sync rotates for at least two seconds', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _ManualSyncApi(
      () async => const SyncResult(changes: [], latestRevision: 0),
    );
    await _pumpRemoteCue(tester, api);

    await tester.tap(find.byKey(const Key('sidebar-sync')));
    await tester.pump();

    Animation<double> rotation() => tester
        .widget<RotationTransition>(
          find.byKey(const Key('sidebar-sync-rotation')),
        )
        .turns;

    expect(rotation().isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 250));
    expect(rotation().value, lessThan(0));
    await tester.pump(const Duration(milliseconds: 750));
    expect(rotation().isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(rotation().isAnimating, isFalse);
    expect(find.byKey(const Key('sidebar-sync-failed')), findsNothing);
  });

  testWidgets('manual sync keeps rotating until a slow sync completes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final sync = Completer<SyncResult>();
    final api = _ManualSyncApi(() => sync.future);
    await _pumpRemoteCue(tester, api);

    await tester.tap(find.byKey(const Key('sidebar-sync')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));

    final rotation = tester
        .widget<RotationTransition>(
          find.byKey(const Key('sidebar-sync-rotation')),
        )
        .turns;
    expect(rotation.isAnimating, isTrue);

    sync.complete(const SyncResult(changes: [], latestRevision: 0));
    await tester.pumpAndSettle();
    expect(rotation.isAnimating, isFalse);
  });

  testWidgets('manual sync shows a retryable failure icon', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _ManualSyncApi(() async => throw const ApiException('Offline'));
    await _pumpRemoteCue(tester, api);

    await tester.tap(find.byKey(const Key('sidebar-sync')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.byKey(const Key('sidebar-sync-failed')), findsOneWidget);
    expect(find.byTooltip('Sync failed · click to retry'), findsOneWidget);
  });

  testWidgets('desktop new task dialog uses the task details popover style', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-add-task-button')));
    await tester.pumpAndSettle();

    final dialogFinder = find.byKey(const Key('desktop-new-task-dialog'));
    expect(dialogFinder, findsOneWidget);
    final dialog = tester.widget<Dialog>(dialogFinder);
    expect(dialog.elevation, 24);
    expect(dialog.backgroundColor, CueColors.popover);
    expect(dialog.insetPadding, CueInsets.dialog);
    expect(dialog.clipBehavior, Clip.antiAlias);
    expect(
      dialog.shape,
      RoundedRectangleBorder(
        side: BorderSide(color: CueColors.strongBorder),
        borderRadius: BorderRadius.circular(16),
      ),
    );
    expect(
      find.byKey(const Key('desktop-new-task-title-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('desktop-new-task-priority-picker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('desktop-new-task-group-picker')),
      findsOneWidget,
    );
    expect(find.text('Status'), findsNothing);
    expect(find.text('To do'), findsNothing);
    expect(find.text('Doing'), findsNothing);
    expect(find.text('Done'), findsNothing);
    expect(find.text('Important'), findsNothing);

    await tester.tap(find.byKey(const Key('desktop-new-task-duedate-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cue-date-picker-popover')), findsOneWidget);
    expect(find.byKey(const Key('cue-date-picker-time')), findsOneWidget);
  });

  testWidgets('desktop task lists hide the header add task button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    void expectQuickAddOnly() {
      expect(find.text('Add task'), findsNothing);
      expect(find.byKey(const Key('quick-add-field')), findsOneWidget);
      expect(find.text('⌘ K'), findsNothing);
      expect(find.text('Add'), findsOneWidget);
    }

    expectQuickAddOnly();

    for (final key in ['sidebar-upcoming', 'sidebar-list']) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expectQuickAddOnly();
    }
  });

  testWidgets('desktop pages share the design-system content gutter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    expect(CueSpacing.desktopPageGutter, CueSpacing.s32);
    expect(CueSpacing.desktopPageTop, CueSpacing.s32);

    EdgeInsets pagePadding() =>
        tester
                .widget<Padding>(find.byKey(const Key('desktop-page-padding')))
                .padding
            as EdgeInsets;

    final fixedPageInsets = defaultTargetPlatform == TargetPlatform.macOS
        ? CueInsets.macosDesktopFixedPage
        : CueInsets.desktopFixedPage;
    final boardPageInsets = defaultTargetPlatform == TargetPlatform.macOS
        ? CueInsets.macosDesktopBoardPage
        : CueInsets.desktopBoardPage;
    final scrollablePageInsets = defaultTargetPlatform == TargetPlatform.macOS
        ? CueInsets.macosDesktopScrollablePage
        : CueInsets.desktopScrollablePage;
    final expectedPageTop = defaultTargetPlatform == TargetPlatform.macOS
        ? CueSpacing.macosDesktopPageTop
        : CueSpacing.desktopPageTop;

    expect(pagePadding(), scrollablePageInsets);
    expect(pagePadding().left, CueSpacing.desktopPageGutter);
    expect(pagePadding().top, expectedPageTop);

    await tester.tap(find.byKey(const Key('sidebar-board')));
    await tester.pumpAndSettle();

    expect(pagePadding(), boardPageInsets);
    expect(pagePadding().left, CueSpacing.desktopPageGutter);
    expect(pagePadding().right, 0);
    expect(pagePadding().top, expectedPageTop);
    expect(
      tester.getSize(find.byKey(const Key('board-scroll-end-gutter'))).width,
      CueSpacing.desktopPageGutter,
    );

    await tester.tap(find.byKey(const Key('sidebar-upcoming')));
    await tester.pumpAndSettle();

    expect(pagePadding(), scrollablePageInsets);
    expect(pagePadding().left, CueSpacing.desktopPageGutter);
    expect(pagePadding().top, expectedPageTop);

    await tester.tap(find.byKey(const Key('sidebar-calendar')));
    await tester.pumpAndSettle();

    expect(pagePadding(), fixedPageInsets);
    expect(pagePadding().left, CueSpacing.desktopPageGutter);
    expect(pagePadding().top, expectedPageTop);
  });

  testWidgets('task list switch keeps quick capture top-aligned', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    Finder quickCaptureFor(CueView view) => find.descendant(
      of: find.byKey(ValueKey(view)),
      matching: find.byKey(const Key('quick-add-field')),
    );

    final initialTop = tester.getTopLeft(quickCaptureFor(CueView.today)).dy;

    await tester.tap(find.byKey(const Key('sidebar-upcoming')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    expect(quickCaptureFor(CueView.today), findsOneWidget);
    expect(quickCaptureFor(CueView.upcoming), findsOneWidget);
    expect(tester.getTopLeft(quickCaptureFor(CueView.today)).dy, initialTop);
    expect(tester.getTopLeft(quickCaptureFor(CueView.upcoming)).dy, initialTop);

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(quickCaptureFor(CueView.upcoming)).dy, initialTop);
  });

  testWidgets('desktop page headers stay outside scrolling content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    void expectFixedHeader() {
      expect(find.byKey(const Key('desktop-page-header')), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(const Key('desktop-page-header')),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    }

    expectFixedHeader();
    for (final key in [
      'sidebar-board',
      'sidebar-upcoming',
      'sidebar-list',
      'sidebar-calendar',
      'sidebar-quadrants',
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expectFixedHeader();
    }
  });

  testWidgets('desktop task pages scroll only the task rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-list')));
    await tester.pumpAndSettle();

    final pageHeader = find.byKey(const Key('desktop-page-header'));
    final quickCapture = find.byKey(const Key('desktop-quick-capture'));
    final listHeader = find.byKey(const Key('desktop-task-list-header'));
    final taskList = find.byKey(const Key('desktop-task-list-scroll'));
    final headerTop = tester.getTopLeft(pageHeader).dy;
    final quickCaptureTop = tester.getTopLeft(quickCapture).dy;
    final listHeaderTop = tester.getTopLeft(listHeader).dy;
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: taskList, matching: find.byType(Scrollable)),
    );

    expect(scrollable.position.pixels, 0);
    await tester.drag(taskList, const Offset(0, -360));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.getTopLeft(pageHeader).dy, headerTop);
    expect(tester.getTopLeft(quickCapture).dy, quickCaptureTop);
    expect(tester.getTopLeft(listHeader).dy, listHeaderTop);
  });

  testWidgets('desktop board renames a group inline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-board')));
    await tester.pumpAndSettle();

    final prioritySection = find.byKey(const Key('group-priority-研发事项-3'));
    final priorityTopBeforeEditing = tester.getTopLeft(prioritySection).dy;
    expect(
      tester.getSize(find.byKey(const Key('group-header-研发事项'))).height,
      36,
    );

    await tester.tap(find.byKey(const Key('group-name-text-研发事项')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-name-field-研发事项')), findsOneWidget);
    expect(tester.getTopLeft(prioritySection).dy, priorityTopBeforeEditing);
    expect(
      tester.getSize(find.byKey(const Key('group-header-研发事项'))).height,
      36,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('group-name-field-研发事项')))
          .focusNode
          ?.hasFocus,
      isTrue,
    );

    await tester.tapAt(const Offset(1300, 900));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-name-field-研发事项')), findsNothing);

    await tester.tap(find.byKey(const Key('group-name-text-研发事项')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('group-name-field-研发事项')),
      '产品研发',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('产品研发'), findsOneWidget);
    expect(find.text('研发事项'), findsNothing);

    final groupMenuFinder = find.byKey(const Key('group-menu-产品研发'));
    final groupMenu = tester.widget<PopupMenuButton<String>>(groupMenuFinder);
    expect(groupMenu.position, PopupMenuPosition.under);
    expect(groupMenu.offset, const Offset(-132, 6));
    expect(groupMenu.constraints, const BoxConstraints.tightFor(width: 160));
    expect(groupMenu.color, CueColors.popover);
    expect(groupMenu.surfaceTintColor, Colors.transparent);

    final menuButtonRect = tester.getRect(groupMenuFinder);
    await tester.tap(groupMenuFinder);
    await tester.pumpAndSettle();
    final deleteMenuItemFinder = find.byKey(
      const Key('group-menu-delete-产品研发'),
    );
    final deleteMenuItem = tester.widget<PopupMenuItem<String>>(
      deleteMenuItemFinder,
    );
    expect(deleteMenuItem.height, 36);
    expect(
      find.descendant(
        of: deleteMenuItemFinder,
        matching: find.byIcon(Icons.delete_outline_rounded),
      ),
      findsOneWidget,
    );
    final deleteMenuItemRect = tester.getRect(deleteMenuItemFinder);
    expect(deleteMenuItemRect.top, greaterThan(menuButtonRect.bottom));
    expect(deleteMenuItemRect.right, lessThan(menuButtonRect.right));
    expect(find.text('Rename Section'), findsNothing);
    expect(find.text('Delete Section'), findsOneWidget);
  });

  testWidgets('desktop board reorders columns from the header drag handle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-board')));
    await tester.pumpAndSettle();

    final socialColumn = find.byKey(const Key('group-col-社会事项'));
    final developmentColumn = find.byKey(const Key('group-col-研发事项'));
    final developmentHandle = find.byKey(const Key('group-drag-handle-研发事项'));
    expect(
      tester.getTopLeft(socialColumn).dx,
      lessThan(tester.getTopLeft(developmentColumn).dx),
    );

    final dragStart = tester.getCenter(developmentHandle);
    final dragEnd = tester.getCenter(socialColumn);
    final columnSize = tester.getSize(developmentColumn);
    final gesture = await tester.startGesture(dragStart);
    await gesture.moveBy(const Offset(-48, 0));
    await tester.pump();

    final dragFeedback = find.byKey(const Key('group-drag-feedback-研发事项'));
    expect(tester.getSize(dragFeedback), columnSize);
    final feedbackTopLeft = tester.getTopLeft(dragFeedback);
    final originalTopLeft = tester.getTopLeft(developmentColumn);
    expect(feedbackTopLeft.dx, closeTo(originalTopLeft.dx - 48, 0.1));
    expect(feedbackTopLeft.dy, closeTo(originalTopLeft.dy, 0.1));
    final draggedColumnOpacity = find.descendant(
      of: developmentColumn,
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(draggedColumnOpacity).opacity, 0.25);

    await gesture.moveTo(dragEnd);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(developmentColumn).dx,
      lessThan(tester.getTopLeft(socialColumn).dx),
    );
  });

  testWidgets('quick capture adds a task to Today', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('quick-add-field')),
      'Prepare demo notes',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Prepare demo notes'), findsOneWidget);
    expect(find.text('Task added to Today'), findsOneWidget);
  });

  testWidgets('desktop task popover edits a synced task note', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review PCB layout'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('desktop-task-details-popover')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('desktop-task-note-text')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('desktop-task-note-field')),
      'Check connector labels',
    );
    await tester.tap(find.byKey(const Key('desktop-task-details-popover')));
    await tester.pumpAndSettle();

    expect(find.text('Check connector labels'), findsOneWidget);
  });

  testWidgets('desktop task action menu follows the Cue popover style', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review PCB layout'));
    await tester.pumpAndSettle();

    final menuFinder = find.byKey(const Key('desktop-task-actions-menu'));
    final menu = tester.widget<PopupMenuButton<String>>(menuFinder);
    expect(menu.position, PopupMenuPosition.over);
    expect(menu.offset, const Offset(0, -90));
    expect(menu.constraints, const BoxConstraints.tightFor(width: 160));
    expect(menu.color, CueColors.popover);
    expect(menu.surfaceTintColor, Colors.transparent);
    expect(menu.menuPadding, const EdgeInsets.all(6));

    final menuButtonRect = tester.getRect(menuFinder);
    await tester.tap(menuFinder);
    await tester.pumpAndSettle();

    final completeItemFinder = find.byKey(
      const Key('desktop-task-action-complete'),
    );
    final deleteItemFinder = find.byKey(
      const Key('desktop-task-action-delete'),
    );
    final completeItem = tester.widget<PopupMenuItem<String>>(
      completeItemFinder,
    );
    final deleteItem = tester.widget<PopupMenuItem<String>>(deleteItemFinder);
    expect(completeItem.height, 36);
    expect(deleteItem.height, 36);
    final completeItemRect = tester.getRect(completeItemFinder);
    final deleteItemRect = tester.getRect(deleteItemFinder);
    expect(deleteItemRect.bottom, lessThan(menuButtonRect.top));
    expect(deleteItemRect.right, closeTo(menuButtonRect.right - 6, 0.1));
    expect(completeItemRect.left, greaterThan(menuButtonRect.left - 160));
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });

  testWidgets('desktop empty task note uses the concise note placeholder', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-board')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('整理机架'));
    await tester.pumpAndSettle();

    final note = find.byKey(const Key('desktop-task-note-text'));
    expect(note, findsOneWidget);
    expect(
      find.descendant(of: note, matching: find.text('Note')),
      findsOneWidget,
    );
  });

  testWidgets(
    'completed task details hides an empty note and edits completion date',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const CueApp.demo());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('sidebar-board')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('组装模拟器'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('desktop-task-details-popover')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('desktop-task-note-text')), findsNothing);
      expect(find.textContaining('Sep 12, 2026 00:00'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('desktop-task-completed-at-picker')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('cue-completion-date-picker-popover')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cue-date-picker-time')), findsOneWidget);
      expect(find.text('清除'), findsNothing);

      await tester.tap(find.text('15'));
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sep 15, 2026 00:00'), findsOneWidget);
    },
  );

  testWidgets('renders the Figma V2 mobile shell and Settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    expect(find.text('CUE'), findsNothing);
    expect(find.text('Sunday, September 13'), findsOneWidget);
    expect(find.text('Review PCB layout'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Quadrants'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final settingsTitle = tester.widget<Text>(
      find.byKey(const Key('mobile-settings-title')),
    );
    expect(settingsTitle.style, CueMobileNavigationTokens.pageTitleTextStyle);
    expect(find.text('Personalize Cue for the way you work'), findsOneWidget);
    expect(find.text('My Cue'), findsOneWidget);
    expect(find.text('System default'), findsNWidgets(2));
    expect(find.text('Default view'), findsOneWidget);
    expect(find.text('Today'), findsNWidgets(2));
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Import & sync'), findsOneWidget);
    expect(find.text('Local demo'), findsOneWidget);
    expect(find.text('Date & time'), findsNothing);
    expect(find.text('Reminders'), findsNothing);
    expect(find.text('Widgets'), findsNothing);
    expect(find.text('AI features'), findsNothing);
    expect(find.text('Help & guide'), findsNothing);
  });

  testWidgets('mobile settings configure the next-launch default view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default view'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('default-view-option-board')), findsOneWidget);
    expect(find.byKey(const Key('default-view-option-today')), findsOneWidget);
    expect(
      find.byKey(const Key('default-view-option-calendar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('default-view-option-quadrants')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('default-view-option-upcoming')), findsNothing);
    expect(find.byKey(const Key('default-view-option-list')), findsNothing);

    await tester.tap(find.byKey(const Key('default-view-option-calendar')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CueHome)),
      listen: false,
    );
    expect(
      container.read(appControllerProvider).startupView,
      StartupView.calendar,
    );
    expect(find.text('Calendar'), findsNWidgets(2));
    expect(find.text('Personalize Cue for the way you work'), findsOneWidget);
  });

  testWidgets('mobile Today aligns its leading icon and omits annotations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    final menuIcon = find.descendant(
      of: find.byKey(const Key('mobile-drawer-button')),
      matching: find.byIcon(Icons.menu_rounded),
    );
    final todayFilter = find.byKey(const Key('mobile-today-filter-today'));
    expect(
      tester.getTopLeft(menuIcon).dx,
      closeTo(tester.getTopLeft(todayFilter).dx, 0.01),
    );
    expect(find.text('MORNING · 2'), findsNothing);
    expect(find.text('LATER · 2'), findsNothing);

    await tester.tap(find.byKey(const Key('mobile-today-filter-later')));
    await tester.pumpAndSettle();

    expect(find.textContaining('UPCOMING ·'), findsNothing);
  });

  testWidgets('mobile pages omit the header overflow action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    void expectNoOverflowAction() {
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    }

    expectNoOverflowAction();

    await tester.tap(find.byKey(const Key('mobile-drawer-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-drawer-board')));
    await tester.pumpAndSettle();
    expectNoOverflowAction();

    for (final destination in ['Calendar', 'Quadrants', 'Settings']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();
      expectNoOverflowAction();
    }
  });

  testWidgets('all mobile pages respect the top system safe area', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.padding = const FakeViewPadding(top: 48);
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetPadding();
    });

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    final safeTop = tester.view.padding.top / tester.view.devicePixelRatio;
    expect(safeTop, greaterThan(0));

    void expectSafePage() {
      final safeArea = tester.widget<SafeArea>(
        find.byKey(const Key('mobile-content-safe-area')),
      );
      expect(safeArea.top, isTrue);
      expect(safeArea.left, isTrue);
      expect(safeArea.right, isTrue);
      expect(safeArea.bottom, isFalse);
      expect(
        tester.getTopLeft(find.byType(ListView).first).dy,
        greaterThanOrEqualTo(safeTop),
      );
    }

    expectSafePage();

    await tester.tap(find.byKey(const Key('mobile-drawer-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-drawer-board')));
    await tester.pumpAndSettle();
    expectSafePage();

    for (final destination in ['Calendar', 'Quadrants', 'Settings']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();
      expectSafePage();
    }
  });

  testWidgets('mobile new task sheet opens the custom due date picker', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-quick-add')));
    await tester.pumpAndSettle();

    final dueDatePicker = find.byKey(
      const Key('mobile-new-task-duedate-picker'),
    );
    expect(dueDatePicker, findsOneWidget);
    await tester.ensureVisible(dueDatePicker);
    await tester.tap(dueDatePicker);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cue-date-picker-popover')), findsOneWidget);
    expect(find.byKey(const Key('cue-date-picker-time')), findsOneWidget);
  });

  testWidgets('mobile new task sheet owns its text field lifecycle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-quick-add')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Lifecycle-safe task');
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Lifecycle-safe task'), findsOneWidget);
  });

  testWidgets('mobile drawer switches between Today and Board', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets);
    await tester.tap(find.byKey(const Key('mobile-drawer-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-navigation-drawer')), findsOneWidget);
    expect(find.byKey(const Key('mobile-drawer-today')), findsOneWidget);
    expect(find.byKey(const Key('mobile-drawer-board')), findsOneWidget);
    final drawer = tester.widget<Drawer>(
      find.byKey(const Key('mobile-navigation-drawer')),
    );
    expect(drawer.width, CueMobileNavigationTokens.drawerWidth);
    expect(drawer.backgroundColor, CueMobileNavigationTokens.drawerSurface);
    expect(drawer.surfaceTintColor, CueMobileNavigationTokens.surfaceTint);
    final drawerBrand = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('mobile-navigation-drawer')),
        matching: find.text('Cue'),
      ),
    );
    expect(drawerBrand.style, CueMobileNavigationTokens.brandTextStyle);
    final selectedToday = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('mobile-drawer-today')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(selectedToday.color, CueMobileNavigationTokens.selectedBackground);
    final selectedTodayLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('mobile-drawer-today')),
        matching: find.text('Today'),
      ),
    );
    expect(
      selectedTodayLabel.style,
      CueMobileNavigationTokens.itemLabelStyle(selected: true),
    );

    await tester.tap(find.byKey(const Key('mobile-drawer-board')));
    await tester.pumpAndSettle();

    expect(find.text('Board'), findsOneWidget);
    expect(
      find.byKey(const Key('mobile-board-group-switcher')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-board-group-社会事项')),
      findsOneWidget,
    );
    final selectedGroup = tester.widget<Material>(
      find.byKey(const ValueKey('mobile-board-group-社会事项')),
    );
    expect(selectedGroup.color, CueMobileBoardTokens.selectedBackground);
    expect(find.text('整理机架'), findsOneWidget);
    expect(find.text('桌面灯设计'), findsNothing);
    expect(find.text('To do'), findsNothing);
    expect(find.text('Doing'), findsNothing);
    expect(find.text('Done'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mobile-board-group-研发事项')));
    await tester.pumpAndSettle();

    expect(find.text('桌面灯设计'), findsOneWidget);
    expect(find.text('整理机架'), findsNothing);

    await tester.tap(find.byKey(const Key('mobile-drawer-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-drawer-today')));
    await tester.pumpAndSettle();

    expect(find.text('Sunday, September 13'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-drawer-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-drawer-board')));
    await tester.pumpAndSettle();

    expect(find.text('桌面灯设计'), findsOneWidget);
    expect(find.text('整理机架'), findsNothing);
  });

  testWidgets('mobile creates a custom Board group and adds into it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-drawer-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-drawer-board')));
    await tester.pumpAndSettle();

    final addGroup = find.byKey(const Key('mobile-board-add-group'));
    await tester.ensureVisible(addGroup);
    await tester.tap(addGroup);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('mobile-add-group-name-field')),
      'Mobile group',
    );
    await tester.tap(find.byKey(const Key('mobile-add-group-submit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-board-group-Mobile group')),
      findsOneWidget,
    );
    expect(find.text('Nothing here — enjoy the space.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-quick-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Task in mobile group',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await tester.pumpAndSettle();

    expect(find.text('Task in mobile group'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the V2 mobile task details dialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review PCB layout'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const Key('task-details-dialog')), findsOneWidget);
    expect(find.byKey(const Key('mobile-task-note-text')), findsOneWidget);
    expect(find.text('Aa'), findsNothing);
    expect(find.text('Doing'), findsNothing);
    expect(find.byTooltip('Close task details'), findsOneWidget);

    await tester.tap(find.byTooltip('Close task details'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('deleting from the mobile task dialog closes only the dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review PCB layout'));
    await tester.pumpAndSettle();

    final dialogMenu = find
        .descendant(
          of: find.byKey(const Key('task-details-dialog')),
          matching: find.byType(PopupMenuButton<String>),
        )
        .last;
    await tester.tap(dialogMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Run thermal simulation'), findsOneWidget);
  });

  testWidgets('switches the interface from English to Chinese', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('language-option-en')),
        matching: find.byIcon(Icons.text_format_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('language-option-zh')));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsWidgets);
    expect(find.text('让 Cue 更适合你的工作方式'), findsOneWidget);
    expect(find.text('我的 Cue'), findsOneWidget);
    expect(find.text('导入与同步'), findsOneWidget);
  });

  testWidgets('desktop language and appearance use the same dialog position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    final languageDialog = find.byType(Dialog);
    expect(languageDialog, findsOneWidget);
    final languageCenter = tester.getCenter(languageDialog);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    final appearanceDialog = find.byType(Dialog);
    expect(appearanceDialog, findsOneWidget);
    expect(tester.getCenter(appearanceDialog), languageCenter);
  });

  testWidgets(
    'desktop task details popover updates title, priority, and due date',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const CueApp.demo());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review PCB layout'));
      await tester.pumpAndSettle();

      // Edit title
      await tester.tap(find.byKey(const Key('desktop-task-title-text')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('desktop-task-title-field')),
        'Review revised PCB layout',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Review revised PCB layout'), findsWidgets);

      // Edit priority
      await tester.tap(find.byKey(const Key('desktop-task-priority-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('P1').last);
      await tester.pumpAndSettle();
      expect(find.text('P1'), findsWidgets);

      // Edit due date
      await tester.tap(find.byKey(const Key('desktop-task-duedate-picker')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cue-date-picker-popover')), findsOneWidget);
      await tester.tap(find.text('20').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'time picker dialog aligns with Cue design tokens and can be set and cleared',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const CueApp.demo());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review PCB layout'));
      await tester.pumpAndSettle();

      // Open date picker
      await tester.tap(find.byKey(const Key('desktop-task-duedate-picker')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cue-date-picker-popover')), findsOneWidget);
      expect(find.byKey(const Key('cue-date-picker-time')), findsOneWidget);

      // Verify initial time button shows default time
      expect(find.text('10:30'), findsOneWidget);

      // Open time picker dialog
      await tester.tap(find.byKey(const Key('cue-date-picker-time')));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsOneWidget);

      // Verify TimePickerThemeData in Theme
      final timePickerTheme = Theme.of(
        tester.element(find.byType(TimePickerDialog)),
      ).timePickerTheme;
      expect(timePickerTheme.backgroundColor, CueColors.popover);
      expect(timePickerTheme.dialBackgroundColor, CueColors.subtle);
      expect(timePickerTheme.dialHandColor, CueColors.accent);
      final hourMinuteColor =
          timePickerTheme.hourMinuteColor as WidgetStateColor;
      final hourMinuteTextColor =
          timePickerTheme.hourMinuteTextColor as WidgetStateColor;
      expect(
        hourMinuteColor.resolve({WidgetState.selected}),
        CueColors.selected,
      );
      expect(hourMinuteColor.resolve({}), CueColors.subtle);
      expect(
        hourMinuteTextColor.resolve({WidgetState.selected}),
        CueColors.accent,
      );
      expect(hourMinuteTextColor.resolve({}), CueColors.primary);

      // Confirm time picker
      await tester.tap(
        find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.text('OK'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsNothing);

      // Clear time using the close icon
      expect(find.byTooltip('清除时间'), findsOneWidget);
      await tester.tap(find.byTooltip('清除时间'));
      await tester.pumpAndSettle();
      expect(find.text('全天'), findsOneWidget);
      expect(find.byTooltip('清除时间'), findsNothing);
    },
  );
}

Future<void> _pumpRemoteCue(WidgetTester tester, _ManualSyncApi api) async {
  final store = TaskStore.remote(api);
  addTearDown(store.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [taskStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        theme: CueTheme.active,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const CueHome(
          userEmail: 'test@cue.local',
          serverUrl: 'http://127.0.0.1:8080',
        ),
      ),
    ),
  );
  await tester.pump();
}

class _ManualSyncApi extends ApiClient {
  _ManualSyncApi(this._sync) : super(TokenStore());

  final Future<SyncResult> Function() _sync;

  @override
  Future<SyncResult> sync(int since) => _sync();

  @override
  Stream<int> watchRevisions() => const Stream.empty();
}
