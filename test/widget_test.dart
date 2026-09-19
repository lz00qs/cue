import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/main.dart';
import 'package:cue/ui/cue_theme.dart';

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
    }

    expectTheme();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.text('CUE'), findsOneWidget);
    expectTheme();
  });

  testWidgets(
    'resizing between desktop and mobile preserves selected page',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const CueApp.demo());
      await tester.pumpAndSettle();

      // Switch to Calendar on desktop
      await tester.tap(find.text('Calendar'));
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
      expect(find.textContaining('Importance × urgency'), findsWidgets);

      // Resize back to desktop
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      await tester.pumpAndSettle();
      // Should remain on Quadrants view
      expect(find.textContaining('Importance × urgency'), findsWidgets);
    },
  );

  testWidgets('appearance can be changed on desktop and mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Appearance'));
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

  testWidgets(
    'system theme mode responds to system platform brightness changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(() => tester.platformDispatcher.clearPlatformBrightnessTestValue());

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

    expect(find.text('Cue'), findsOneWidget);
    expect(find.text('Focus for today'), findsOneWidget);
    expect(find.text('Review PCB layout'), findsOneWidget);

    await tester.tap(find.text('Board'));
    await tester.pumpAndSettle();

    expect(find.text('Three focused stages, one task model'), findsOneWidget);
    expect(find.textContaining('TODO ·'), findsOneWidget);
    expect(find.textContaining('DOING ·'), findsOneWidget);
    expect(find.textContaining('DONE ·'), findsOneWidget);
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
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('desktop-task-note-field')),
      'Check connector labels',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Check connector labels'), findsOneWidget);
  });

  testWidgets('renders the Figma V2 mobile shell and Settings', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    expect(find.text('CUE'), findsOneWidget);
    expect(find.text('Sunday, September 13'), findsOneWidget);
    expect(find.text('Review PCB layout'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Quadrants'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Personalize Cue for the way you work'), findsOneWidget);
    expect(find.text('System default'), findsNWidgets(2));
    expect(find.text('Import & sync'), findsOneWidget);
    expect(find.text('Local demo'), findsOneWidget);
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
    expect(find.text('+  Add notes or a checklist…'), findsOneWidget);
    expect(find.text('Aa'), findsNothing);
    expect(find.text('Doing'), findsOneWidget);
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

    final dialogMenu = find.descendant(
      of: find.byKey(const Key('task-details-dialog')),
      matching: find.byType(PopupMenuButton<String>),
    ).last;
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
    expect(find.text('导入与同步'), findsOneWidget);
  });

  testWidgets('desktop language and appearance use the same dialog position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Language'));
    await tester.pumpAndSettle();
    final languageDialog = find.byType(Dialog);
    expect(languageDialog, findsOneWidget);
    final languageCenter = tester.getCenter(languageDialog);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Appearance'));
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

      // Edit due date to Tomorrow
      await tester.tap(find.byKey(const Key('desktop-task-duedate-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      expect(find.text('Tomorrow'), findsWidgets);
    },
  );
}
