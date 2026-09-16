import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/main.dart';

void main() {
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
    );
    await tester.tap(dialogMenu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Run thermal simulation'), findsOneWidget);
  });
}
