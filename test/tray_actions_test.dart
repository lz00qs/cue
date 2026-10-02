import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/main.dart';
import 'package:cue/tray_handler.dart';
import 'package:cue/ui/cue_widgets.dart';

void main() {
  testWidgets('tray create task opens the desktop task form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();
    trayCreateTaskRequests.value++;
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-new-task-dialog')), findsOneWidget);
    expect(
      find.byKey(const Key('desktop-new-task-title-field')),
      findsOneWidget,
    );
    final priorityBadge = find.descendant(
      of: find.byKey(const Key('desktop-new-task-priority-picker')),
      matching: find.byType(CuePriorityBadge),
    );
    expect(tester.widget<CuePriorityBadge>(priorityBadge).priority, 3);
  });

  testWidgets('tray create task opens the compact task form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CueApp.demo());
    await tester.pumpAndSettle();

    trayCreateTaskRequests.value++;
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('New task'), findsOneWidget);
  });
}
