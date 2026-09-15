import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/task_store.dart';
import '../../models/cue_task.dart';
import '../cue_theme.dart';
import '../cue_widgets.dart';

class BoardView extends StatefulWidget {
  const BoardView({super.key, required this.store, required this.onOpenTask});

  final TaskStore store;
  final ValueChanged<CueTask> onOpenTask;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  String _group = 'Status';

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
                label: 'Status',
                selected: _group == 'Status',
                onTap: () => setState(() => _group = 'Status'),
              ),
              const SizedBox(width: 8),
              CueViewTab(
                label: 'Priority',
                selected: _group == 'Priority',
                onTap: () => setState(() => _group = 'Priority'),
              ),
              const SizedBox(width: 8),
              CueViewTab(
                label: 'Due date',
                selected: _group == 'Due date',
                onTap: () => setState(() => _group = 'Due date'),
              ),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width >= 720)
                Text(
                  _group == 'Status'
                      ? 'Drag cards to update status'
                      : 'Demo grouping preview',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: CueColors.tertiary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_group == 'Status')
          _StatusBoard(store: widget.store, onOpenTask: widget.onOpenTask)
        else
          _GroupedPreview(
            store: widget.store,
            group: _group,
            onOpenTask: widget.onOpenTask,
          ),
      ],
    );
  }
}

class _StatusBoard extends StatelessWidget {
  const _StatusBoard({required this.store, required this.onOpenTask});

  final TaskStore store;
  final ValueChanged<CueTask> onOpenTask;

  List<CueTask> _tasks(CueTaskStatus status) {
    return store.tasksForStatus(status);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final columnWidth = compact ? 300.0 : (constraints.maxWidth - 32) / 3;
        final board = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BoardColumn(
              width: columnWidth,
              title: 'TODO',
              status: CueTaskStatus.todo,
              tasks: _tasks(CueTaskStatus.todo),
              onAccept: (task) => unawaited(
                store.moveToStatus(task, CueTaskStatus.todo).catchError((_) {}),
              ),
              onOpenTask: onOpenTask,
            ),
            const SizedBox(width: 16),
            _BoardColumn(
              width: columnWidth,
              title: 'DOING',
              status: CueTaskStatus.doing,
              tasks: _tasks(CueTaskStatus.doing),
              onAccept: (task) => unawaited(
                store
                    .moveToStatus(task, CueTaskStatus.doing)
                    .catchError((_) {}),
              ),
              onOpenTask: onOpenTask,
            ),
            const SizedBox(width: 16),
            _BoardColumn(
              width: columnWidth,
              title: 'DONE',
              status: CueTaskStatus.done,
              tasks: _tasks(CueTaskStatus.done),
              onAccept: (task) => unawaited(
                store.moveToStatus(task, CueTaskStatus.done).catchError((_) {}),
              ),
              onOpenTask: onOpenTask,
            ),
          ],
        );
        if (!compact) return board;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: board,
        );
      },
    );
  }
}

class _BoardColumn extends StatefulWidget {
  const _BoardColumn({
    required this.width,
    required this.title,
    required this.status,
    required this.tasks,
    required this.onAccept,
    required this.onOpenTask,
  });

  final double width;
  final String title;
  final CueTaskStatus status;
  final List<CueTask> tasks;
  final ValueChanged<CueTask> onAccept;
  final ValueChanged<CueTask> onOpenTask;

  @override
  State<_BoardColumn> createState() => _BoardColumnState();
}

class _BoardColumnState extends State<_BoardColumn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<CueTask>(
      onWillAcceptWithDetails: (details) {
        setState(() => _hovering = details.data.status != widget.status);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        widget.onAccept(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: widget.width,
          height: 720,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovering ? CueColors.selected : CueColors.subtle,
            border: Border.all(
              color: _hovering ? CueColors.accent : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.title} · ${widget.tasks.length}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.48,
                  color: CueColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: widget.tasks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final task = widget.tasks[index];
                    return Draggable<CueTask>(
                      data: task,
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: widget.width - 24,
                          child: CueTaskCard(task: task, onOpen: () {}),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: CueTaskCard(
                          task: task,
                          onOpen: () => widget.onOpenTask(task),
                        ),
                      ),
                      child: CueTaskCard(
                        task: task,
                        onOpen: () => widget.onOpenTask(task),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupedPreview extends StatelessWidget {
  const _GroupedPreview({
    required this.store,
    required this.group,
    required this.onOpenTask,
  });

  final TaskStore store;
  final String group;
  final ValueChanged<CueTask> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final tasks = store.tasks.where((task) => task.deletedAt == null).toList();
    tasks.sort(
      (a, b) => group == 'Priority'
          ? a.priority.compareTo(b.priority)
          : (a.dueAt ?? DateTime(2099)).compareTo(b.dueAt ?? DateTime(2099)),
    );
    return Container(
      height: 720,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CueColors.subtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisExtent: 96,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return CueTaskCard(task: task, onOpen: () => onOpenTask(task));
        },
      ),
    );
  }
}
