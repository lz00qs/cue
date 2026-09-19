import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';

import '../../data/task_store.dart';
import '../../l10n/l10n.dart';
import '../../models/cue_task.dart';
import '../cue_theme.dart';
import '../cue_widgets.dart';

class TaskDetailsPopover extends ConsumerStatefulWidget {
  const TaskDetailsPopover({
    super.key,
    required this.initialTask,
    required this.onRun,
    required this.onDelete,
    required this.onClose,
  });

  final CueTask initialTask;
  final Future<bool> Function(Future<void> Function()) onRun;
  final Future<void> Function(CueTask) onDelete;
  final VoidCallback onClose;

  @override
  ConsumerState<TaskDetailsPopover> createState() => _TaskDetailsPopoverState();
}

class _TaskDetailsPopoverState extends ConsumerState<TaskDetailsPopover> {
  TaskStore get _store => ref.read(taskStoreProvider)!;
  late final TextEditingController _noteController;
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _noteFocusNode;
  bool _editingNote = false;
  bool _editingTitle = false;
  CueTask? _currentTask;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialTask.note);
    _titleController = TextEditingController(text: widget.initialTask.title);
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_onTitleFocusChange);
    _noteFocusNode = FocusNode();
    _noteFocusNode.addListener(_onNoteFocusChange);
  }

  void _onTitleFocusChange() {
    if (!_titleFocusNode.hasFocus && _editingTitle) {
      _saveTitle();
    }
  }

  void _onNoteFocusChange() {
    if (!_noteFocusNode.hasFocus && _editingNote) {
      _saveNote();
    }
  }

  Future<void> _saveTitle() async {
    if (!_editingTitle) return;
    final task = _currentTask;
    if (task == null) return;
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != task.title) {
      await widget.onRun(() => _store.updateTitle(task, newTitle));
    }
    if (mounted) {
      setState(() => _editingTitle = false);
    }
  }

  Future<void> _saveNote() async {
    if (!_editingNote) return;
    final task = _currentTask;
    if (task == null) return;
    final newNote = _noteController.text.trim();
    if (newNote != task.note) {
      await widget.onRun(() => _store.updateNote(task, newNote));
    }
    if (mounted) {
      setState(() => _editingNote = false);
    }
  }

  @override
  void dispose() {
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _titleFocusNode.dispose();
    _noteFocusNode.removeListener(_onNoteFocusChange);
    _noteFocusNode.dispose();
    _noteController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(taskRevisionProvider);
    final matches = _store.tasks.where(
      (item) => item.id == widget.initialTask.id,
    );
    final task = matches.isEmpty ? widget.initialTask : matches.first;
    _currentTask = task;
    return Dialog(
      key: const Key('desktop-task-details-popover'),
      alignment: Alignment.center,
      insetPadding: const EdgeInsets.all(24),
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.72),
      backgroundColor: CueColors.popover,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: CueColors.strongBorder),
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
                    onTap: () =>
                        widget.onRun(() => _store.toggleComplete(task)),
                    child: SvgPicture.asset(
                      task.isCompleted
                          ? 'assets/figma/checkbox-completed.svg'
                          : 'assets/figma/checkbox.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: PopupMenuButton<String>(
                        key: const Key('desktop-task-duedate-picker'),
                        tooltip: context.l10n.dueDate,
                        offset: const Offset(0, 32),
                        color: CueColors.card,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: CueColors.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: (value) async {
                          if (value == 'today') {
                            final t = _store.today;
                            widget.onRun(
                              () => _store.updateDueAt(
                                task,
                                DateTime(t.year, t.month, t.day, 18),
                              ),
                            );
                          } else if (value == 'tomorrow') {
                            final t = _store.today.add(const Duration(days: 1));
                            widget.onRun(
                              () => _store.updateDueAt(
                                task,
                                DateTime(t.year, t.month, t.day, 18),
                              ),
                            );
                          } else if (value == 'pick') {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: task.dueAt ?? _store.today,
                              firstDate: DateTime(_store.today.year - 1),
                              lastDate: DateTime(_store.today.year + 5),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.dark(
                                      primary: CueColors.accent,
                                      surface: CueColors.popover,
                                      onSurface: CueColors.primary,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              final newDue = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                task.dueAt?.hour ?? 18,
                                task.dueAt?.minute ?? 0,
                              );
                              widget.onRun(
                                () => _store.updateDueAt(task, newDue),
                              );
                            }
                          } else if (value == 'clear') {
                            widget.onRun(() => _store.updateDueAt(task, null));
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'today',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.today,
                                  size: 16,
                                  color: CueColors.accent,
                                ),
                                const SizedBox(width: 8),
                                Text(context.l10n.today),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'tomorrow',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 16,
                                  color: CueColors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(context.l10n.tomorrow),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'pick',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  size: 16,
                                  color: CueColors.secondary,
                                ),
                                const SizedBox(width: 8),
                                Text('${context.l10n.dueDate}…'),
                              ],
                            ),
                          ),
                          if (task.dueAt != null)
                            PopupMenuItem(
                              value: 'clear',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_busy,
                                    size: 16,
                                    color: CueColors.tertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(context.l10n.noDueDate),
                                ],
                              ),
                            ),
                        ],
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: CueColors.subtle,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 13,
                                  color: task.dueAt != null
                                      ? CueColors.accent
                                      : CueColors.secondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cueCompactTaskMeta(
                                    context,
                                    task,
                                    today: _store.today,
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: task.dueAt != null
                                            ? CueColors.primary
                                            : CueColors.secondary,
                                      ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 14,
                                  color: CueColors.secondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<int>(
                    key: const Key('desktop-task-priority-picker'),
                    tooltip: context.l10n.priority,
                    offset: const Offset(0, 32),
                    color: CueColors.card,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: CueColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (p) {
                      widget.onRun(() => _store.updatePriority(task, p));
                    },
                    itemBuilder: (context) => [
                      for (var p = 0; p < 4; p++)
                        PopupMenuItem<int>(
                          value: p,
                          child: Row(
                            children: [
                              CuePriorityBadge(priority: p),
                              const SizedBox(width: 10),
                              Text(
                                'P$p',
                                style: TextStyle(
                                  color: p == task.priority
                                      ? CueColors.accent
                                      : CueColors.primary,
                                  fontWeight: p == task.priority
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: CuePriorityBadge(priority: task.priority),
                    ),
                  ),
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
                    if (_editingTitle) ...[
                      TextField(
                        key: const Key('desktop-task-title-field'),
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        autofocus: true,
                        style: TextStyle(
                          color: CueColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: context.l10n.taskTitle,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: CueColors.accent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: CueColors.accent, width: 1.5),
                          ),
                        ),
                        onTapOutside: (_) => _saveTitle(),
                        onSubmitted: (_) => _saveTitle(),
                      ),
                    ] else ...[
                      InkWell(
                        key: const Key('desktop-task-title-text'),
                        onTap: () {
                          _titleController.text = task.title;
                          setState(() => _editingTitle = true);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          child: Text(
                            task.title,
                            style: TextStyle(
                              color: CueColors.primary,
                              fontSize: 20,
                              height: 25 / 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
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
                        focusNode: _noteFocusNode,
                        autofocus: true,
                        maxLines: 4,
                        style: TextStyle(
                          color: CueColors.primary,
                          fontSize: 15,
                          height: 21 / 15,
                        ),
                        decoration: InputDecoration(
                          hintText: context.l10n.note,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: CueColors.accent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: CueColors.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onTapOutside: (_) => _saveNote(),
                      ),
                    ] else ...[
                      InkWell(
                        key: const Key('desktop-task-note-text'),
                        onTap: () {
                          _noteController.text = task.note;
                          setState(() => _editingNote = true);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 4,
                          ),
                          child: Text(
                            task.note.isEmpty
                                ? context.l10n.defaultTaskNote
                                : task.note,
                            style: TextStyle(
                              color: task.note.isEmpty
                                  ? CueColors.secondary
                                  : CueColors.primary,
                              fontSize: 15,
                              height: 21 / 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: CueColors.border)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => widget.onRun(
                      () => _store.moveToStatus(task, CueTaskStatus.todo),
                    ),
                    child: Text(context.l10n.inbox),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => widget.onRun(
                      () => _store.moveToStatus(task, CueTaskStatus.doing),
                    ),
                    child: Text(context.l10n.doing),
                  ),
                  PopupMenuButton<String>(
                    tooltip: context.l10n.moreOptions,
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onSelected: (value) {
                      if (value == 'complete') {
                        widget.onRun(() => _store.toggleComplete(task));
                      } else if (value == 'important') {
                        widget.onRun(() => _store.toggleImportant(task));
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
  }
}
