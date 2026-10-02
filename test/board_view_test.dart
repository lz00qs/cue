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
  final today = DateTime(2026, 12, 31);

  for (final locale in ['en', 'zh']) {
    testWidgets(
      'priority column buttons create tasks in their columns ($locale)',
      (tester) async {
        final store = TaskStore([], today: today)..addGroup('Team');
        await _pumpBoard(tester, store, locale);
        await tester.tap(
          find.widgetWithText(CueViewTab, locale == 'zh' ? '优先级' : 'Priority'),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.add_rounded), findsNWidgets(4));
        for (var priority = 0; priority < 4; priority++) {
          final button = find.byKey(Key('board-add-priority-$priority'));
          await tester.tap(button);
          await tester.pumpAndSettle();
          final badge = find.descendant(
            of: find.byKey(const Key('desktop-new-task-priority-picker')),
            matching: find.byType(CuePriorityBadge),
          );
          expect(tester.widget<CuePriorityBadge>(badge).priority, priority);

          final title = 'New P$priority task';
          await _submitTask(tester, title);
          final task = store.tasks.last;
          expect(task.title, title);
          expect(task.priority, priority);
          expect(task.group, isNull);
          expect(task.dueAt, DateTime(2026, 12, 31, 18));
          expect(find.text(title), findsOneWidget);
          expect(find.text('P$priority · 1'), findsOneWidget);
        }
      },
    );

    testWidgets(
      'due date column buttons create tasks in their columns ($locale)',
      (tester) async {
        final store = TaskStore([], today: today)..addGroup('Team');
        await _pumpBoard(tester, store, locale);
        await tester.tap(
          find.widgetWithText(CueViewTab, locale == 'zh' ? '截止日期' : 'Due date'),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.add_rounded), findsNWidgets(3));
        expect(find.byKey(const Key('board-add-dueDate-0')), findsNothing);
        final expectedDates = [
          DateTime(2026, 12, 31, 18),
          DateTime(2027, 1, 1, 18),
          null,
        ];
        final columnLabels = locale == 'zh'
            ? ['今天', '即将到来', '无截止日期']
            : ['Today', 'Upcoming', 'No due date'];
        for (var index = 0; index < expectedDates.length; index++) {
          final button = find.byKey(Key('board-add-dueDate-${index + 1}'));
          await tester.tap(button);
          await tester.pumpAndSettle();
          if (expectedDates[index] == null) {
            expect(
              find.descendant(
                of: find.byKey(const Key('desktop-new-task-duedate-picker')),
                matching: find.text(columnLabels[index]),
              ),
              findsOneWidget,
            );
          }

          final title = 'New ${columnLabels[index]} task';
          await _submitTask(tester, title);
          final task = store.tasks.last;
          expect(task.title, title);
          expect(task.dueAt, expectedDates[index]);
          expect(task.priority, 2);
          expect(task.group, isNull);
          expect(find.text(title), findsOneWidget);
          expect(find.text('${columnLabels[index]} · 1'), findsOneWidget);
        }
      },
    );

    testWidgets('due date board separates overdue tasks from today ($locale)', (
      tester,
    ) async {
      CueTask task(
        String title,
        DateTime? dueAt, {
        DateTime? deletedAt,
        DateTime? completedAt,
      }) => CueTask(
        id: title,
        title: title,
        note: '',
        priority: 2,
        sortOrder: 1000,
        dueAt: dueAt,
        createdAt: today,
        updatedAt: today,
        deletedAt: deletedAt,
        completedAt: completedAt,
      );

      final yesterdayTask = task(
        'Yesterday task',
        DateTime(2026, 12, 30, 23, 59),
      );
      final store = TaskStore([
        yesterdayTask,
        task('Older task', DateTime(2026, 12, 1, 18)),
        task('Today midnight task', today),
        task('Today evening task', DateTime(2026, 12, 31, 23, 59)),
        task('Tomorrow task', DateTime(2027, 1, 1)),
        task('Unscheduled task', null),
        task('Deleted task', DateTime(2026, 12, 30), deletedAt: today),
        task('Completed task', DateTime(2026, 12, 30), completedAt: today),
      ], today: today);
      await _pumpBoard(tester, store, locale);
      await tester.tap(
        find.widgetWithText(CueViewTab, locale == 'zh' ? '截止日期' : 'Due date'),
      );
      await tester.pumpAndSettle();

      final overdueLabel = locale == 'zh' ? '已逾期' : 'Overdue';
      final todayLabel = locale == 'zh' ? '今天' : 'Today';
      final upcomingLabel = locale == 'zh' ? '即将到来' : 'Upcoming';
      final noDueDateLabel = locale == 'zh' ? '无截止日期' : 'No due date';

      void expectColumn(String label, List<String> titles) {
        final header = find.text('$label · ${titles.length}');
        expect(header, findsOneWidget);
        final column = find
            .ancestor(of: header, matching: find.byType(Column))
            .first;
        final cards = find.descendant(
          of: column,
          matching: find.byType(CueTaskCard),
        );
        expect(
          tester.widgetList<CueTaskCard>(cards).map((card) => card.task.title),
          titles,
        );
      }

      expectColumn(overdueLabel, ['Older task', 'Yesterday task']);
      expectColumn(todayLabel, ['Today midnight task', 'Today evening task']);
      expectColumn(upcomingLabel, ['Tomorrow task']);
      expectColumn(noDueDateLabel, ['Unscheduled task']);
      expect(find.text('Deleted task'), findsNothing);
      expect(find.text('Completed task'), findsNothing);
      expect(find.byType(CueTaskCard), findsNWidgets(6));

      await store.updateDueAt(yesterdayTask, DateTime(2026, 12, 31, 18));
      await tester.pumpAndSettle();
      expectColumn(overdueLabel, ['Older task']);
      expectColumn(todayLabel, [
        'Today midnight task',
        'Yesterday task',
        'Today evening task',
      ]);
      expect(find.byType(CueTaskCard), findsNWidgets(6));
    });
  }
}

Future<void> _pumpBoard(
  WidgetTester tester,
  TaskStore store,
  String locale,
) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(store.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [taskStoreProvider.overrideWithValue(store)],
      child: MaterialApp(
        theme: CueTheme.active,
        locale: Locale(locale),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const CueHome(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('sidebar-board')));
  await tester.pumpAndSettle();
}

Future<void> _submitTask(WidgetTester tester, String title) async {
  await tester.enterText(
    find.byKey(const Key('desktop-new-task-title-field')),
    title,
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('desktop-new-task-submit')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('desktop-new-task-dialog')), findsNothing);
}
