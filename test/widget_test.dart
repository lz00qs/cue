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
}
