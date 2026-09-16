import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/task_store.dart';
import '../../l10n/l10n.dart';
import '../../models/cue_task.dart';
import '../cue_theme.dart';
import '../cue_widgets.dart';

class TaskDetailsPopover extends StatefulWidget {
  const TaskDetailsPopover({
    super.key,
    required this.initialTask,
    required this.store,
    required this.onRun,
    required this.onDelete,
    required this.onClose,
  });

  final CueTask initialTask;
  final TaskStore store;
  final Future<bool> Function(Future<void> Function()) onRun;
  final Future<void> Function(CueTask) onDelete;
  final VoidCallback onClose;

  @override
  State<TaskDetailsPopover> createState() => _TaskDetailsPopoverState();
}

class _TaskDetailsPopoverState extends State<TaskDetailsPopover> {
  late final TextEditingController _noteController;
  bool _editingNote = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialTask.note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final matches = widget.store.tasks.where(
          (item) => item.id == widget.initialTask.id,
        );
        final task = matches.isEmpty ? widget.initialTask : matches.first;
        return Dialog(
          key: const Key('desktop-task-details-popover'),
          alignment: const Alignment(0.72, -0.14),
          insetPadding: const EdgeInsets.all(24),
          elevation: 12,
          backgroundColor: CueColors.canvas,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: CueColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 440,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () => widget.onRun(
                          () => widget.store.toggleComplete(task),
                        ),
                        child: SvgPicture.asset(
                          task.isCompleted
                              ? 'assets/figma/checkbox-completed.svg'
                              : 'assets/figma/checkbox.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          cueCompactTaskMeta(
                            context,
                            task,
                            today: widget.store.today,
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      CuePriorityBadge(priority: task.priority),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close, size: 18),
                        color: CueColors.secondary,
                        tooltip: context.l10n.closeTaskDetails,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            color: CueColors.primary,
                            fontSize: 20,
                            height: 25 / 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${cueTaskArea(context, task)} · ${context.l10n.createdOn(formatShortMonthDay(context, task.createdAt))}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (_editingNote) ...[
                          TextField(
                            key: const Key('desktop-task-note-field'),
                            controller: _noteController,
                            autofocus: true,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: context.l10n.notes,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () =>
                                    setState(() => _editingNote = false),
                                child: Text(context.l10n.cancel),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final saved = await widget.onRun(
                                    () => widget.store.updateNote(
                                      task,
                                      _noteController.text,
                                    ),
                                  );
                                  if (saved && mounted) {
                                    setState(() => _editingNote = false);
                                  }
                                },
                                child: Text(context.l10n.save),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            task.note.isEmpty
                                ? context.l10n.defaultTaskNote
                                : task.note,
                            style: const TextStyle(
                              color: CueColors.primary,
                              fontSize: 15,
                              height: 21 / 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              _noteController.text = task.note;
                              setState(() => _editingNote = true);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: CueColors.tertiary,
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(context.l10n.notes),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: CueColors.border)),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => widget.onRun(
                          () => widget.store.moveToStatus(
                            task,
                            CueTaskStatus.todo,
                          ),
                        ),
                        child: Text(context.l10n.inbox),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => widget.onRun(
                          () => widget.store.moveToStatus(
                            task,
                            CueTaskStatus.doing,
                          ),
                        ),
                        child: Text(context.l10n.doing),
                      ),
                      PopupMenuButton<String>(
                        tooltip: context.l10n.moreOptions,
                        icon: const Icon(Icons.more_horiz, size: 20),
                        onSelected: (value) {
                          if (value == 'complete') {
                            widget.onRun(
                              () => widget.store.toggleComplete(task),
                            );
                          } else if (value == 'important') {
                            widget.onRun(
                              () => widget.store.toggleImportant(task),
                            );
                          } else if (value == 'delete') {
                            widget.onDelete(task);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'complete',
                            child: Text(context.l10n.toggleComplete),
                          ),
                          PopupMenuItem(
                            value: 'important',
                            child: Text(context.l10n.important),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(context.l10n.delete),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
