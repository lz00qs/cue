import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/main.dart';
import 'package:cue/tray_handler.dart';

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
