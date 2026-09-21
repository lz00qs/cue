import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/main.dart';
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
    }

    expectTheme();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.text('CUE'), findsOneWidget);
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
    await tester.tap(find.text('Quadrants'));
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
      expect(
        find.descendant(
          of: find.byKey(ValueKey('quadrant-panel-$priority')),
          matching: find.byKey(ValueKey('quadrant-priority-$priority')),
        ),
        findsOneWidget,
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

  testWidgets('renders the Cue Today view and switches to Inbox board', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    expect(find.text('Cue'), findsOneWidget);
    expect(find.text('Focus for today'), findsOneWidget);
    expect(find.text('Review PCB layout'), findsOneWidget);

    await tester.tap(find.text('Inbox'));
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

  testWidgets('desktop new task dialog omits status and importance controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-add-task-button')));
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Priority'), findsOneWidget);
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
      expect(find.text('Add'), findsOneWidget);
    }

    expectQuickAddOnly();

    for (final page in ['Upcoming', 'List']) {
      await tester.tap(find.text(page).first);
      await tester.pumpAndSettle();
      expectQuickAddOnly();
    }
  });

  testWidgets('desktop inbox renames a group inline', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inbox'));
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

  testWidgets('desktop inbox reorders columns from the header drag handle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inbox'));
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

  testWidgets(
    'completed task details hides an empty note and edits completion date',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const CueApp.demo());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('组装模拟器'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('desktop-task-details-popover')),
        findsOneWidget,
      );
      expect(
        find.text('A focused next action in your Cue workspace.'),
        findsNothing,
      );
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

  testWidgets('mobile board groups tasks without workflow status tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Board'));
    await tester.pumpAndSettle();

    expect(find.text('社会事项 · 7'), findsOneWidget);
    expect(find.text('To do'), findsNothing);
    expect(find.text('Doing'), findsNothing);
    expect(find.text('Done'), findsNothing);
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
}
