import 'package:flutter/material.dart';

import '../../data/task_store.dart';
import '../../l10n/l10n.dart';
import '../../models/cue_task.dart';
import '../cue_theme.dart';
import '../cue_widgets.dart';

class QuadrantsView extends StatefulWidget {
  const QuadrantsView({
    super.key,
    required this.store,
    required this.onOpenTask,
  });

  final TaskStore store;
  final ValueChanged<CueTask> onOpenTask;

  @override
  State<QuadrantsView> createState() => _QuadrantsViewState();
}

class _QuadrantsViewState extends State<QuadrantsView> {
  _QuadrantFilter _filter = _QuadrantFilter.all;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              CueViewTab(
                label: context.l10n.allTasksFilter,
                selected: _filter == _QuadrantFilter.all,
                onTap: () => setState(() => _filter = _QuadrantFilter.all),
              ),
              const SizedBox(width: 8),
              CueViewTab(
                label: context.l10n.importantFilter,
                selected: _filter == _QuadrantFilter.important,
                onTap: () =>
                    setState(() => _filter = _QuadrantFilter.important),
              ),
              const SizedBox(width: 8),
              CueViewTab(
                label: context.l10n.dueSoon,
                selected: _filter == _QuadrantFilter.dueSoon,
                onTap: () => setState(() => _filter = _QuadrantFilter.dueSoon),
              ),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width >= 720)
                Text(
                  context.l10n.urgentDefinition,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: CueColors.tertiary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final panels = [
              _panel(
                context,
                title: context.l10n.doNow,
                rule: context.l10n.doNowRule,
                color: CueColors.danger,
                important: true,
                urgent: true,
              ),
              _panel(
                context,
                title: context.l10n.schedule,
                rule: context.l10n.scheduleRule,
                color: CueColors.orange,
                important: true,
                urgent: false,
              ),
              _panel(
                context,
                title: context.l10n.batch,
                rule: context.l10n.batchRule,
                color: CueColors.accent,
                important: false,
                urgent: true,
              ),
              _panel(
                context,
                title: context.l10n.reconsider,
                rule: context.l10n.reconsiderRule,
                color: CueColors.green,
                important: false,
                urgent: false,
              ),
            ];
            if (compact) {
              return Column(
                children: panels
                    .expand((panel) => [panel, const SizedBox(height: 16)])
                    .toList(),
              );
            }
            return Column(
              children: [
                SizedBox(
                  height: 336,
                  child: Row(
                    children: [
                      Expanded(child: panels[0]),
                      const SizedBox(width: 16),
                      Expanded(child: panels[1]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 336,
                  child: Row(
                    children: [
                      Expanded(child: panels[2]),
                      const SizedBox(width: 16),
                      Expanded(child: panels[3]),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _panel(
    BuildContext context, {
    required String title,
    required String rule,
    required Color color,
    required bool important,
    required bool urgent,
  }) {
    var tasks = widget.store
        .quadrantTasks(important: important, urgent: urgent)
        .toList();
    if (_filter == _QuadrantFilter.important && !important) tasks = [];
    if (_filter == _QuadrantFilter.dueSoon && !urgent) tasks = [];
    return _QuadrantPanel(
      title: title,
      rule: rule,
      color: color,
      tasks: tasks,
      today: widget.store.today,
      onOpenTask: widget.onOpenTask,
    );
  }
}

class _QuadrantPanel extends StatelessWidget {
  const _QuadrantPanel({
    required this.title,
    required this.rule,
    required this.color,
    required this.tasks,
    required this.today,
    required this.onOpenTask,
  });

  final String title;
  final String rule;
  final Color color;
  final List<CueTask> tasks;
  final DateTime today;
  final ValueChanged<CueTask> onOpenTask;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 336,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CueColors.canvas,
        border: Border.all(color: CueColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: color),
          ),
          const SizedBox(height: 8),
          Text(
            rule,
            style: const TextStyle(
              color: CueColors.tertiary,
              fontSize: 11,
              height: 13 / 11,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: tasks.isEmpty
                ? const _EmptyQuadrant()
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.take(2).length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return CueTaskCard(
                        task: task,
                        referenceDate: today,
                        onOpen: () => onOpenTask(task),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyQuadrant extends StatelessWidget {
  const _EmptyQuadrant();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.l10n.noMatchingTasks,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: CueColors.tertiary),
      ),
    );
  }
}

enum _QuadrantFilter { all, important, dueSoon }
