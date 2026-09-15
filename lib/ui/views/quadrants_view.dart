import 'package:flutter/material.dart';

import '../../data/task_store.dart';
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
  String _filter = 'All tasks';

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
                label: 'All tasks',
                selected: _filter == 'All tasks',
                onTap: () => setState(() => _filter = 'All tasks'),
              ),
              const SizedBox(width: 8),
              CueViewTab(
                label: 'Important',
                selected: _filter == 'Important',
                onTap: () => setState(() => _filter = 'Important'),
              ),
              const SizedBox(width: 8),
              CueViewTab(
                label: 'Due soon',
                selected: _filter == 'Due soon',
                onTap: () => setState(() => _filter = 'Due soon'),
              ),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width >= 720)
                Text(
                  'Urgent = due within 2 days',
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
                title: 'Do now',
                rule: 'Important · due within 2 days',
                color: CueColors.danger,
                important: true,
                urgent: true,
              ),
              _panel(
                context,
                title: 'Schedule',
                rule: 'Important · not urgent',
                color: CueColors.orange,
                important: true,
                urgent: false,
              ),
              _panel(
                context,
                title: 'Batch',
                rule: 'Due soon · lower importance',
                color: CueColors.accent,
                important: false,
                urgent: true,
              ),
              _panel(
                context,
                title: 'Reconsider',
                rule: 'Neither important nor urgent',
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
    if (_filter == 'Important' && !important) tasks = [];
    if (_filter == 'Due soon' && !urgent) tasks = [];
    return _QuadrantPanel(
      title: title,
      rule: rule,
      color: color,
      tasks: tasks,
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
    required this.onOpenTask,
  });

  final String title;
  final String rule;
  final Color color;
  final List<CueTask> tasks;
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
        'No matching tasks',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: CueColors.tertiary),
      ),
    );
  }
}
