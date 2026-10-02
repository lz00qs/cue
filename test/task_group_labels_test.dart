import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/data/task_store.dart';
import 'package:cue/l10n/l10n.dart';
import 'package:cue/models/cue_task.dart';
import 'package:cue/state/app_state.dart';
import 'package:cue/ui/cue_home.dart';
import 'package:cue/ui/cue_theme.dart';
import 'package:cue/ui/cue_widgets.dart';

void main() {
  final today = DateTime(2026, 10, 2);

  for (final locale in ['en', 'zh']) {
    for (final entry in [
      (name: 'desktop Add button', mobile: false, keyboard: false),
      (name: 'desktop keyboard', mobile: false, keyboard: true),
      (name: 'mobile Add button', mobile: true, keyboard: false),
    ]) {
      testWidgets('${entry.name} creates an ungrouped task ($locale)', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(
          entry.mobile ? const Size(390, 844) : const Size(1440, 1000),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final store = TaskStore([], today: today)..addGroup('产品');
        addTearDown(store.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [taskStoreProvider.overrideWithValue(store)],
            child: _localizedApp(const CueHome(), locale: locale),
          ),
        );
        await tester.pumpAndSettle();

        if (entry.mobile) {
          await tester.tap(find.byKey(const Key('mobile-quick-add')));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField).first, 'test');
          await tester.pump();
          await tester.tap(
            find.widgetWithText(
              FilledButton,
              locale == 'zh' ? '添加任务' : 'Add task',
            ),
          );
        } else {
          await tester.enterText(
            find.byKey(const Key('quick-add-field')),
            'test',
          );
          if (entry.keyboard) {
            await tester.testTextInput.receiveAction(TextInputAction.done);
          } else {
            await tester.tap(
              find.widgetWithText(TextButton, locale == 'zh' ? '添加' : 'Add'),
            );
          }
        }
        await tester.pumpAndSettle();

        expect(store.tasks.single.group, isNull);
        expect(store.tasks.single.priority, 3);
        expect(store.tasks.single.dueAt, DateTime(2026, 10, 2, 18));
        expect(find.text('test'), findsOneWidget);
        final dateLabel = entry.mobile
            ? '18:00'
            : '${locale == 'zh' ? '今天' : 'Today'}, 18:00';
        expect(find.text(dateLabel), findsOneWidget);

        await store.updateGroup(store.tasks.single, '实际分组');
        await tester.pumpAndSettle();
        expect(find.text('$dateLabel · 实际分组'), findsOneWidget);

        await store.updateGroup(store.tasks.single, TaskStore.defaultUngrouped);
        await tester.pumpAndSettle();
        expect(store.tasks.single.group, isNull);
        expect(find.text(dateLabel), findsOneWidget);
        expect(find.text('$dateLabel · 实际分组'), findsNothing);

        if (entry.mobile) {
          await tester.tap(find.text('test'));
          await tester.pumpAndSettle();
          // Verify the creation date without any group prefix.
          final context = tester.element(
            find.byKey(const Key('task-details-dialog')),
          );
          final created = store.tasks.single.createdAt;
          final createdLabel = TaskStore.isSameDay(created, today)
              ? context.l10n.createdToday
              : formatShortMonthDay(context, created);
          expect(
            find.text(context.l10n.createdOn(createdLabel)),
            findsOneWidget,
          );
        }
      });
    }
  }

  testWidgets('desktop task rows ignore legacy demo labels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = TaskStore([
      CueTask(
        id: 'lab-calibration',
        title: 'Calibrate lab equipment',
        note: '',
        priority: 2,
        sortOrder: 1000,
        dueAt: DateTime(2026, 10, 2, 18),
        createdAt: today,
        updatedAt: today,
      ),
    ], today: today);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskStoreProvider.overrideWithValue(store)],
        child: _localizedApp(const CueHome()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Today, 18:00'), findsOneWidget);

    await store.updateGroup(store.tasks.single, 'Lab team');
    await tester.pumpAndSettle();
    expect(find.text('Today, 18:00 · Lab team'), findsOneWidget);
  });

  for (final schedule in [
    (
      name: 'today',
      dueAt: DateTime(2026, 10, 2, 18),
      completedAt: null,
      label: 'Today, 18:00',
    ),
    (name: 'no due date', dueAt: null, completedAt: null, label: 'No due date'),
    (
      name: 'overdue',
      dueAt: DateTime(2026, 10, 1, 18),
      completedAt: null,
      label: 'Oct 1, 2026',
    ),
    (
      name: 'upcoming',
      dueAt: DateTime(2026, 10, 3, 18),
      completedAt: null,
      label: 'Oct 3',
    ),
    (
      name: 'completed',
      dueAt: DateTime(2026, 10, 2, 18),
      completedAt: DateTime(2026, 10, 2, 11, 30),
      label: 'Completed 11:30',
    ),
  ]) {
    testWidgets('${schedule.name} metadata shows only an actual group', (
      tester,
    ) async {
      final groups = [
        null,
        '',
        '  ',
        TaskStore.defaultUngrouped,
        ' 未分组 ',
        ' Team ',
      ];
      await tester.pumpWidget(
        _localizedApp(
          Builder(
            builder: (context) => Column(
              children: [
                for (final group in groups)
                  Text(
                    cueTaskMeta(
                      context,
                      CueTask(
                        id: 'task-$group',
                        title: 'PCB thermal signal report lab',
                        note: '',
                        priority: 2,
                        sortOrder: 1000,
                        createdAt: today,
                        updatedAt: today,
                        dueAt: schedule.dueAt,
                        completedAt: schedule.completedAt,
                        group: group,
                      ),
                      today: today,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      expect(find.text(schedule.label), findsNWidgets(5));
      expect(find.text('${schedule.label} · Team'), findsOneWidget);
    });
  }
}

Widget _localizedApp(Widget home, {String locale = 'en'}) => MaterialApp(
  theme: CueTheme.active,
  locale: Locale(locale),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: home,
);
