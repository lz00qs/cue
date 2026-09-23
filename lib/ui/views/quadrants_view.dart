import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../data/task_store.dart';
import '../../l10n/l10n.dart';
import '../../models/cue_task.dart';
import '../cue_theme.dart';

class QuadrantsView extends ConsumerStatefulWidget {
  const QuadrantsView({super.key, required this.onOpenTask});

  final ValueChanged<CueTask> onOpenTask;

  @override
  ConsumerState<QuadrantsView> createState() => _QuadrantsViewState();
}

class _QuadrantsViewState extends ConsumerState<QuadrantsView> {
  TaskStore get _store => ref.read(taskStoreProvider)!;

  @override
  Widget build(BuildContext context) {
    ref.watch(taskRevisionProvider);
    final panels = [
      _panel(title: context.l10n.doNow, priority: 0),
      _panel(title: context.l10n.schedule, priority: 1),
      _panel(title: context.l10n.batch, priority: 2),
      _panel(title: context.l10n.reconsider, priority: 3),
    ];
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: panels[0]),
              const SizedBox(width: CueQuadrantTokens.panelGap),
              Expanded(child: panels[1]),
            ],
          ),
        ),
        const SizedBox(height: CueQuadrantTokens.panelGap),
        Expanded(
          child: Row(
            children: [
              Expanded(child: panels[2]),
              const SizedBox(width: CueQuadrantTokens.panelGap),
              Expanded(child: panels[3]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel({required String title, required int priority}) {
    final tasks = _store.tasksForPriority(priority).toList();
    return _QuadrantPanel(
      key: ValueKey('quadrant-panel-$priority'),
      title: title,
      priority: priority,
      tasks: tasks,
      onOpenTask: widget.onOpenTask,
      onToggleTask: (task) async {
        try {
          await _store.toggleComplete(task);
        } catch (_) {
          // The store rolls the optimistic change back on failure.
        }
      },
      onMoveTask: (task) async {
        try {
          await _store.updatePriority(task, priority);
        } catch (_) {
          // The store rolls the optimistic change back on failure.
        }
      },
    );
  }
}

class _QuadrantPanel extends StatelessWidget {
  const _QuadrantPanel({
    super.key,
    required this.title,
    required this.priority,
    required this.tasks,
    required this.onOpenTask,
    required this.onToggleTask,
    required this.onMoveTask,
  });

  final String title;
  final int priority;
  final List<CueTask> tasks;
  final ValueChanged<CueTask> onOpenTask;
  final ValueChanged<CueTask> onToggleTask;
  final ValueChanged<CueTask> onMoveTask;

  @override
  Widget build(BuildContext context) {
    final accentColor = CueQuadrantTokens.accentForPriority(priority);
    return DragTarget<CueTask>(
      onWillAcceptWithDetails: (details) => details.data.priority != priority,
      onAcceptWithDetails: (details) => onMoveTask(details.data),
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: CueQuadrantTokens.panelPadding,
          decoration: BoxDecoration(
            color: CueQuadrantTokens.panelBackground,
            border: Border.all(
              color: isDropTarget ? accentColor : CueQuadrantTokens.panelBorder,
            ),
            borderRadius: BorderRadius.circular(CueQuadrantTokens.panelRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: accentColor),
                    ),
                  ),
                  Text(
                    'P$priority',
                    key: ValueKey('quadrant-priority-$priority'),
                    style: CueQuadrantTokens.priorityLabelStyle,
                  ),
                ],
              ),
              const SizedBox(height: CueQuadrantTokens.headerToTasksGap),
              Expanded(
                child: tasks.isEmpty
                    ? const _EmptyQuadrant()
                    : ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context)
                            .copyWith(scrollbars: false),
                        child: ListView.separated(
                          padding: EdgeInsets.zero,
                          primary: false,
                          itemCount: tasks.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: CueQuadrantTokens.taskGap),
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            return _QuadrantTaskTile(
                              key: ValueKey('quadrant-task-${task.id}'),
                              task: task,
                              accentColor: accentColor,
                              onOpen: () => onOpenTask(task),
                              onToggle: () => onToggleTask(task),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuadrantTaskTile extends StatefulWidget {
  const _QuadrantTaskTile({
    super.key,
    required this.task,
    required this.accentColor,
    required this.onOpen,
    required this.onToggle,
  });

  final CueTask task;
  final Color accentColor;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  State<_QuadrantTaskTile> createState() => _QuadrantTaskTileState();
}

class _QuadrantTaskTileState extends State<_QuadrantTaskTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cardContent = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: CueQuadrantTokens.taskHeight,
          padding: CueQuadrantTokens.taskPadding,
          decoration: BoxDecoration(
            color: _hovered
                ? CueQuadrantTokens.taskHoverBackground
                : CueQuadrantTokens.taskBackground,
            border: Border.all(
              color: _hovered
                  ? CueQuadrantTokens.taskHoverBorder
                  : CueQuadrantTokens.taskBorder,
            ),
            borderRadius: BorderRadius.circular(CueQuadrantTokens.taskRadius),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.onToggle,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(CueSpacing.s2),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      border: Border.all(color: widget.accentColor, width: 1.5),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CueQuadrantTokens.taskTitleStyle.copyWith(
                    color: CueColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Draggable<CueTask>(
          data: widget.task,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: constraints.maxWidth, child: cardContent),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: cardContent),
          child: cardContent,
        );
      },
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
