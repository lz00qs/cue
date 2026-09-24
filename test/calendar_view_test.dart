import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/main.dart';
import 'package:cue/ui/cue_theme.dart';

void main() {
  testWidgets('desktop calendar opens the task that was clicked', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-calendar')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-task-thermal-simulation')));
    await tester.pumpAndSettle();

    final popover = find.byKey(const Key('desktop-task-details-popover'));
    expect(popover, findsOneWidget);
    expect(tester.widget<Dialog>(popover).backgroundColor, CueColors.popover);
    expect(tester.widget<Dialog>(popover).alignment, Alignment.center);
    expect(
      find.descendant(
        of: popover,
        matching: find.text('Run thermal simulation'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: popover,
        matching: find.text(
          'Compare the revised enclosure against the baseline model.',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('calendar view scales cells dynamically without horizontal scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-calendar')));
    await tester.pumpAndSettle();

    // Verify there is no horizontal SingleChildScrollView in CalendarView
    final horizontalScrollView = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScrollView, findsNothing);

    // Verify cell sizes adapt to surface width
    final firstCell = find.ancestor(
      of: find.text('2').first,
      matching: find.byType(GestureDetector),
    ).first;
    final firstCellSizeWide = tester.getSize(firstCell);

    await tester.binding.setSurfaceSize(const Size(900, 900));
    await tester.pumpAndSettle();

    final firstCellSizeNarrow = tester.getSize(firstCell);
    expect(firstCellSizeNarrow.width, lessThan(firstCellSizeWide.width));
  });

  testWidgets('calendar header controls navigate months correctly', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-calendar')));
    await tester.pumpAndSettle();

    // Initial month should be September 2026
    expect(find.text('September 2026'), findsOneWidget);

    // Tap next month icon
    await tester.tap(find.byKey(const Key('calendar-next-month')));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);

    // Tap previous month icon twice
    await tester.tap(find.byKey(const Key('calendar-prev-month')));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-prev-month')));
    await tester.pumpAndSettle();
    expect(find.text('August 2026'), findsOneWidget);

    // Tap Today button to return to current month
    await tester.tap(find.byKey(const Key('calendar-today-button')));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
  });

  testWidgets('clicking header title opens month picker popover and changes month', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sidebar-calendar')));
    await tester.pumpAndSettle();

    // Tap title trigger to open month picker popover
    await tester.tap(find.byKey(const Key('calendar-title-picker-trigger')));
    await tester.pumpAndSettle();

    final monthPicker = find.byKey(const Key('month-picker-popover'));
    expect(monthPicker, findsOneWidget);

    // Tap June (6月)
    await tester.tap(find.byKey(const Key('month-picker-item-6')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('month-picker-popover')), findsNothing);
    expect(find.text('June 2026'), findsOneWidget);

    // Open popover again and click circle button to reset to current year & month
    await tester.tap(find.byKey(const Key('calendar-title-picker-trigger')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('month-picker-today-year')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('month-picker-popover')), findsNothing);
    expect(find.text('September 2026'), findsOneWidget);
  });

  testWidgets('mobile calendar day selection shows that day tasks inline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('mobile-calendar-day-2026-09-13')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Next up'), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-calendar-task-pcb-review')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-calendar-task-thermal-simulation')),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-calendar-task-requirements')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-calendar-task-sprint-report')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('mobile-calendar-day-2026-09-15')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('mobile-calendar-day-2026-09-15')),
    );
    await tester.pumpAndSettle();

    final selectedDateLabel = tester.widget<Text>(
      find.byKey(const Key('mobile-calendar-selected-date-label')),
    );
    expect(selectedDateLabel.data, contains('September 15'));
    expect(
      find.byKey(const ValueKey('mobile-calendar-task-signal-drift')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-calendar-task-pcb-review')),
      findsNothing,
    );
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('mobile calendar swipes and selects a year and month', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('mobile-calendar-prev-month')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('mobile-calendar-next-month')),
      findsNothing,
    );

    await tester.fling(
      find.byKey(const Key('mobile-calendar-month-grid')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('mobile-calendar-grid-2026-9')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-calendar-grid-2026-10')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('mobile-calendar-grid-2026-9')),
          )
          .dx,
      lessThan(20),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey('mobile-calendar-grid-2026-10')),
          )
          .dx,
      greaterThan(20),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-calendar-grid-2026-9')),
      findsNothing,
    );
    expect(find.text('October'), findsOneWidget);
    expect(find.text('2026 · month overview'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('mobile-calendar-month-grid')),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('September'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('mobile-calendar-title-picker-trigger')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mobile-month-picker-sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-month-picker-next-year')));
    await tester.pumpAndSettle();
    expect(find.text('2027'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-month-picker-item-6')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-month-picker-sheet')), findsNothing);
    expect(find.text('June'), findsOneWidget);
    expect(find.text('2027 · month overview'), findsOneWidget);
  });
}
