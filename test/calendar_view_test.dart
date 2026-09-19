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
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-task-thermal-simulation')));
    await tester.pumpAndSettle();

    final popover = find.byKey(const Key('desktop-task-details-popover'));
    expect(popover, findsOneWidget);
    expect(tester.widget<Dialog>(popover).backgroundColor, CueColors.popover);
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
}
