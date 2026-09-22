import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';

import '../../data/task_store.dart';
import '../../l10n/l10n.dart';
import '../../models/cue_task.dart';
import '../cue_date_picker.dart';
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

  Future<void> _editDate(CueTask task) async {
    if (task.completedAt != null) {
      final completedAt = await showCueCompletionDatePickerPopover(
        context: context,
        initialCompletedAt: task.completedAt!,
      );
      if (completedAt != null) {
        await widget.onRun(() => _store.updateCompletedAt(task, completedAt));
      }
      return;
    }

    final result = await showCueDatePickerPopover(
      context: context,
      today: _store.today,
      initialDueAt: task.dueAt,
      initialReminder: task.reminder,
      initialRecurrence: task.recurrence,
    );
    if (result == null) return;
    if (result.cleared) {
      await widget.onRun(
        () => _store.updateDueAt(
          task,
          null,
          clearReminder: true,
          clearRecurrence: true,
        ),
      );
    } else {
      await widget.onRun(
        () => _store.updateDueAt(
          task,
          result.dueAt,
          reminder: result.reminder,
          recurrence: result.recurrence,
        ),
      );
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
      insetPadding: CueInsets.dialog,
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
                      child: InkWell(
                        key: Key(
                          task.isCompleted
                              ? 'desktop-task-completed-at-picker'
                              : 'desktop-task-duedate-picker',
                        ),
                        onTap: () => _editDate(task),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CueSpacing.s8,
                            vertical: CueSpacing.s4,
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
                                color: task.isCompleted || task.dueAt != null
                                    ? CueColors.accent
                                    : CueColors.secondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  task.completedAt != null
                                      ? context.l10n.completedAt(
                                          formatFullDateTime(
                                            context,
                                            task.completedAt!,
                                          ),
                                        )
                                      : cueCompactTaskMeta(
                                          context,
                                          task,
                                          today: _store.today,
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color:
                                            task.isCompleted ||
                                                task.dueAt != null
                                            ? CueColors.primary
                                            : CueColors.secondary,
                                      ),
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
                padding: const EdgeInsets.fromLTRB(
                  CueSpacing.s24,
                  CueSpacing.s18,
                  CueSpacing.s24,
                  CueSpacing.s16,
                ),
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
                            horizontal: CueSpacing.s10,
                            vertical: CueSpacing.s8,
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
                            vertical: CueSpacing.s4,
                            horizontal: CueSpacing.s4,
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
                    Row(
                      children: [
                        PopupMenuButton<String>(
                          tooltip: context.l10n.group,
                          offset: const Offset(0, 24),
                          color: CueColors.card,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: CueColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onSelected: (g) {
                            final newGroup = g == TaskStore.defaultUngrouped
                                ? null
                                : g;
                            widget.onRun(
                              () => _store.updateGroup(task, newGroup),
                            );
                          },
                          itemBuilder: (context) => [
                            for (final g in _store.groups)
                              PopupMenuItem<String>(
                                value: g,
                                child: Text(
                                  g,
                                  style: TextStyle(
                                    color:
                                        (task.group ??
                                                TaskStore.defaultUngrouped) ==
                                            g
                                        ? CueColors.accent
                                        : CueColors.primary,
                                    fontWeight:
                                        (task.group ??
                                                TaskStore.defaultUngrouped) ==
                                            g
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CueSpacing.s8,
                              vertical: CueSpacing.s4,
                            ),
                            decoration: BoxDecoration(
                              color: CueColors.subtle,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.folder_outlined,
                                  size: 13,
                                  color: CueColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  task.group ?? TaskStore.defaultUngrouped,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: CueColors.primary),
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
                        const SizedBox(width: 10),
                        Text(
                          '· ${context.l10n.createdOn(formatShortMonthDay(context, task.createdAt))}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (_editingNote ||
                        task.note.isNotEmpty ||
                        !task.isCompleted) ...[
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
                              horizontal: CueSpacing.s10,
                              vertical: CueSpacing.s8,
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
                              vertical: CueSpacing.s4,
                              horizontal: CueSpacing.s4,
                            ),
                            child: Text(
                              task.note.isEmpty ? context.l10n.note : task.note,
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
                  ],
                ),
              ),
            ),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: CueSpacing.s12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: CueColors.border)),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  PopupMenuButton<String>(
                    key: const Key('desktop-task-actions-menu'),
                    tooltip: context.l10n.moreOptions,
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    position: PopupMenuPosition.over,
                    offset: const Offset(0, -90),
                    constraints: const BoxConstraints.tightFor(width: 160),
                    color: CueColors.popover,
                    surfaceTintColor: Colors.transparent,
                    elevation: 12,
                    shadowColor: Colors.black.withValues(alpha: 0.32),
                    menuPadding: const EdgeInsets.all(CueSpacing.s6),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: CueColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: CueColors.secondary,
                    ),
                    onSelected: (value) {
                      if (value == 'complete') {
                        widget.onRun(() => _store.toggleComplete(task));
                      } else if (value == 'delete') {
                        widget.onDelete(task);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        key: const Key('desktop-task-action-complete'),
                        value: 'complete',
                        height: 36,
                        padding: EdgeInsets.zero,
                        child: _TaskActionMenuItemContent(
                          icon: task.isCompleted
                              ? Icons.radio_button_unchecked_rounded
                              : Icons.check_circle_outline_rounded,
                          label: context.l10n.toggleComplete,
                        ),
                      ),
                      PopupMenuItem(
                        key: const Key('desktop-task-action-delete'),
                        value: 'delete',
                        height: 36,
                        padding: EdgeInsets.zero,
                        child: _TaskActionMenuItemContent(
                          icon: Icons.delete_outline_rounded,
                          label: context.l10n.delete,
                          danger: true,
                        ),
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

class _TaskActionMenuItemContent extends StatefulWidget {
  const _TaskActionMenuItemContent({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  State<_TaskActionMenuItemContent> createState() =>
      _TaskActionMenuItemContentState();
}

class _TaskActionMenuItemContentState
    extends State<_TaskActionMenuItemContent> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final foreground = widget.danger ? CueColors.danger : CueColors.primary;
    final hoverColor = widget.danger
        ? CueColors.dangerBackground
        : CueColors.subtle;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: CueSpacing.s10),
        decoration: BoxDecoration(
          color: _hovered ? hoverColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 17, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
