import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../state/page_state.dart';

import '../../data/task_store.dart';
import '../../l10n/l10n.dart';
import '../../models/cue_task.dart';
import '../cue_theme.dart';
import '../cue_widgets.dart';

class BoardView extends ConsumerStatefulWidget {
  const BoardView({super.key, required this.onOpenTask, this.onAddTask});

  final ValueChanged<CueTask> onOpenTask;
  final void Function({String? group, int? priority})? onAddTask;

  @override
  ConsumerState<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<BoardView> {
  BoardGroup get _group => ref.read(boardGroupProvider);
  TaskStore get _store => ref.read(taskStoreProvider)!;

  @override
  Widget build(BuildContext context) {
    ref.watch(taskRevisionProvider);
    ref.watch(boardGroupProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: Row(
            children: [
              CueViewTab(
                label: context.l10n.groupSection,
                selected: _group == BoardGroup.group,
                onTap: () => ref
                    .read(boardGroupProvider.notifier)
                    .select(BoardGroup.group),
              ),
              const SizedBox(width: 8),
              CueViewTab(
                label: context.l10n.groupPriority,
                selected: _group == BoardGroup.priority,
                onTap: () => ref
                    .read(boardGroupProvider.notifier)
                    .select(BoardGroup.priority),
              ),
              const SizedBox(width: 8),
              CueViewTab(
                label: context.l10n.groupDueDate,
                selected: _group == BoardGroup.dueDate,
                onTap: () => ref
                    .read(boardGroupProvider.notifier)
                    .select(BoardGroup.dueDate),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: switch (_group) {
            BoardGroup.group => _GroupSectionBoard(
              store: _store,
              onOpenTask: widget.onOpenTask,
              onAddTask: widget.onAddTask,
            ),
            _ => _GroupedPreview(
              store: _store,
              group: _group,
              onOpenTask: widget.onOpenTask,
            ),
          },
        ),
      ],
    );
  }
}

class _GroupSectionBoard extends StatelessWidget {
  const _GroupSectionBoard({
    required this.store,
    required this.onOpenTask,
    this.onAddTask,
  });

  final TaskStore store;
  final ValueChanged<CueTask> onOpenTask;
  final void Function({String? group, int? priority})? onAddTask;

  @override
  Widget build(BuildContext context) {
    final groups = store.groups;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              maxHeight: constraints.maxHeight,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < groups.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  DragTarget<_GroupColumnDragData>(
                    onWillAcceptWithDetails: (details) =>
                        details.data.group != groups[i],
                    onAcceptWithDetails: (details) {
                      store.moveGroup(details.data.group, groups[i]);
                    },
                    builder: (context, candidateData, rejectedData) {
                      return _GroupColumn(
                        key: ValueKey('group-col-${groups[i]}'),
                        group: groups[i],
                        store: store,
                        onOpenTask: onOpenTask,
                        onAddTask: onAddTask,
                        height: constraints.maxHeight,
                        isColumnDropTarget: candidateData.isNotEmpty,
                      );
                    },
                  ),
                ],
                const SizedBox(width: 16),
                _AddGroupColumn(store: store),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GroupColumnDragData {
  const _GroupColumnDragData(this.group);

  final String group;
}

class _GroupColumn extends StatefulWidget {
  const _GroupColumn({
    super.key,
    required this.group,
    required this.store,
    required this.onOpenTask,
    required this.height,
    this.onAddTask,
    this.isColumnDropTarget = false,
  });

  final String group;
  final TaskStore store;
  final ValueChanged<CueTask> onOpenTask;
  final double height;
  final void Function({String? group, int? priority})? onAddTask;
  final bool isColumnDropTarget;

  @override
  State<_GroupColumn> createState() => _GroupColumnState();
}

class _GroupColumnState extends State<_GroupColumn> {
  bool _hovering = false;
  bool _draggingColumn = false;
  bool _editingName = false;
  final Set<int> _collapsedPriorities = {};
  bool _completedCollapsed = false;
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;
  final GlobalKey _columnKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group);
    _nameFocusNode = FocusNode()..addListener(_onNameFocusChange);
  }

  void _onNameFocusChange() {
    if (!_nameFocusNode.hasFocus && _editingName) {
      _saveName();
    }
  }

  void _startEditingName() {
    if (widget.group == TaskStore.defaultUngrouped) return;
    _nameController.text = widget.group;
    setState(() => _editingName = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editingName) return;
      _nameFocusNode.requestFocus();
      _nameController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameController.text.length,
      );
    });
  }

  void _saveName() {
    if (!_editingName) return;
    final newName = _nameController.text.trim();
    setState(() => _editingName = false);
    if (newName.isNotEmpty && newName != widget.group) {
      widget.store.renameGroup(widget.group, newName);
    }
  }

  @override
  void dispose() {
    _nameFocusNode.removeListener(_onNameFocusChange);
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showDeleteDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.deleteGroup),
        content: Text('${context.l10n.deleteGroup} "${widget.group}"？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CueColors.danger),
            onPressed: () {
              widget.store.deleteGroup(widget.group);
              Navigator.pop(dialogContext);
            },
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showQuickAddDialog({int priority = 2}) {
    final titleController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.addTask),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.taskTitleHint),
          onSubmitted: (value) async {
            if (value.trim().isNotEmpty) {
              await widget.store.addTask(
                title: value,
                priority: priority,
                group: widget.group,
              );
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final value = titleController.text.trim();
              if (value.isNotEmpty) {
                await widget.store.addTask(
                  title: value,
                  priority: priority,
                  group: widget.group,
                );
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: Text(context.l10n.addTask),
          ),
        ],
      ),
    );
  }

  Offset _columnDragAnchorStrategy(
    Draggable<Object> draggable,
    BuildContext handleContext,
    Offset globalPosition,
  ) {
    final renderObject = _columnKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.globalToLocal(globalPosition);
    }
    return childDragAnchorStrategy(draggable, handleContext, globalPosition);
  }

  Widget _buildColumnDragFeedback(
    List<CueTask> activeTasks,
    List<CueTask> completedTasks,
  ) {
    return Material(
      color: Colors.transparent,
      child: Container(
        key: Key('group-drag-feedback-${widget.group}'),
        width: 300,
        height: widget.height,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CueColors.subtle,
          border: Border.all(color: CueColors.accent),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.group,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: CueColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${activeTasks.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: CueColors.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.add_rounded, size: 18, color: CueColors.secondary),
                  const SizedBox(width: 10),
                  if (widget.group != TaskStore.defaultUngrouped)
                    Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: CueColors.secondary,
                    )
                  else
                    const SizedBox(width: 18),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  ..._buildPrioritySections(activeTasks),
                  if (completedTasks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildCompletedSection(completedTasks),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnDragHandle(
    List<CueTask> activeTasks,
    List<CueTask> completedTasks,
  ) {
    return Draggable<_GroupColumnDragData>(
      key: Key('group-drag-handle-${widget.group}'),
      data: _GroupColumnDragData(widget.group),
      axis: Axis.horizontal,
      rootOverlay: true,
      dragAnchorStrategy: _columnDragAnchorStrategy,
      feedback: _buildColumnDragFeedback(activeTasks, completedTasks),
      onDragStarted: () => setState(() => _draggingColumn = true),
      onDragEnd: (_) {
        if (mounted) setState(() => _draggingColumn = false);
      },
      childWhenDragging: MouseRegion(
        cursor: SystemMouseCursors.grabbing,
        child: SizedBox.expand(child: ColoredBox(color: CueColors.selected)),
      ),
      child: const MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: SizedBox.expand(),
      ),
    );
  }

  String _priorityLabel(int priority) {
    return switch (priority) {
      0 => context.l10n.groupPriorityHigh,
      1 => context.l10n.groupPriorityMedium,
      2 => context.l10n.groupPriorityLow,
      _ => context.l10n.groupPriorityNone,
    };
  }

  List<Widget> _buildPrioritySections(List<CueTask> activeTasks) {
    final widgets = <Widget>[];
    const priorities = [0, 1, 2, 3];
    for (final p in priorities) {
      final pTasks = activeTasks.where((t) => t.priority == p).toList();
      if (pTasks.isEmpty && !(p == 3 && activeTasks.isEmpty)) {
        continue;
      }
      final isCollapsed = _collapsedPriorities.contains(p);
      final label = _priorityLabel(p);

      widgets.add(
        Padding(
          key: Key('group-priority-${widget.group}-$p'),
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  setState(() {
                    if (isCollapsed) {
                      _collapsedPriorities.remove(p);
                    } else {
                      _collapsedPriorities.add(p);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCollapsed
                            ? Icons.keyboard_arrow_right_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: CueColors.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$label ${pTasks.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CueColors.secondary,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 16,
                          icon: const Icon(
                            Icons.add_rounded,
                            color: CueColors.tertiary,
                          ),
                          onPressed: () {
                            if (widget.onAddTask != null) {
                              widget.onAddTask!(
                                group: widget.group,
                                priority: p,
                              );
                            } else {
                              _showQuickAddDialog(priority: p);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isCollapsed) ...[
                const SizedBox(height: 4),
                for (final task in pTasks) ...[
                  _TickTickTaskCard(
                    task: task,
                    store: widget.store,
                    onOpen: () => widget.onOpenTask(task),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildCompletedSection(List<CueTask> completedTasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            setState(() => _completedCollapsed = !_completedCollapsed);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                Icon(
                  _completedCollapsed
                      ? Icons.keyboard_arrow_right_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: CueColors.secondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${context.l10n.completed} ${completedTasks.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CueColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!_completedCollapsed) ...[
          const SizedBox(height: 4),
          for (final task in completedTasks) ...[
            _TickTickTaskCard(
              task: task,
              store: widget.store,
              onOpen: () => widget.onOpenTask(task),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTasks = widget.store.activeTasksForGroup(widget.group);
    final completedTasks = widget.store.completedTasksForGroup(widget.group);

    return DragTarget<CueTask>(
      onWillAcceptWithDetails: (details) {
        final currentGroup = details.data.group ?? TaskStore.defaultUngrouped;
        final targetGroup = widget.group;
        final willAccept =
            (currentGroup.isEmpty
                ? TaskStore.defaultUngrouped
                : currentGroup) !=
            (targetGroup.isEmpty ? TaskStore.defaultUngrouped : targetGroup);
        setState(() => _hovering = willAccept);
        return willAccept;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        unawaited(widget.store.updateGroup(details.data, widget.group));
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _draggingColumn ? 0.25 : 1,
          child: AnimatedContainer(
            key: _columnKey,
            duration: const Duration(milliseconds: 140),
            width: 300,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _hovering || widget.isColumnDropTarget
                  ? CueColors.selected
                  : CueColors.subtle,
              border: Border.all(
                color: _hovering || widget.isColumnDropTarget
                    ? CueColors.accent
                    : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column Header
                SizedBox(
                  key: Key('group-header-${widget.group}'),
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: _editingName
                                  ? TapRegion(
                                      onTapOutside: (_) => _saveName(),
                                      child: TextField(
                                        key: Key(
                                          'group-name-field-${widget.group}',
                                        ),
                                        controller: _nameController,
                                        focusNode: _nameFocusNode,
                                        autofocus: true,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: CueColors.primary,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: context.l10n.enterGroupName,
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: CueColors.accent,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            borderSide: BorderSide(
                                              color: CueColors.accent,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        onSubmitted: (_) => _saveName(),
                                      ),
                                    )
                                  : InkWell(
                                      key: Key(
                                        'group-name-text-${widget.group}',
                                      ),
                                      onTap:
                                          widget.group ==
                                              TaskStore.defaultUngrouped
                                          ? null
                                          : _startEditingName,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          widget.group,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: CueColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${activeTasks.length}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: CueColors.tertiary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 64,
                              height: 36,
                              child: _buildColumnDragHandle(
                                activeTasks,
                                completedTasks,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          icon: Icon(
                            Icons.add_rounded,
                            color: CueColors.secondary,
                          ),
                          onPressed: () {
                            if (widget.onAddTask != null) {
                              widget.onAddTask!(group: widget.group);
                            } else {
                              _showQuickAddDialog();
                            }
                          },
                          tooltip: context.l10n.addTask,
                        ),
                      ),
                      if (widget.group != TaskStore.defaultUngrouped)
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: PopupMenuButton<String>(
                            key: Key('group-menu-${widget.group}'),
                            tooltip: context.l10n.moreOptions,
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            position: PopupMenuPosition.under,
                            offset: const Offset(-132, 6),
                            constraints: const BoxConstraints.tightFor(
                              width: 160,
                            ),
                            color: CueColors.popover,
                            surfaceTintColor: Colors.transparent,
                            elevation: 12,
                            shadowColor: Colors.black.withValues(alpha: 0.32),
                            menuPadding: const EdgeInsets.all(6),
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
                              if (value == 'delete') _showDeleteDialog();
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                key: Key('group-menu-delete-${widget.group}'),
                                value: 'delete',
                                height: 36,
                                padding: EdgeInsets.zero,
                                child: _DangerMenuItemContent(
                                  label: context.l10n.deleteGroup,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(width: 28),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Body list
                Expanded(
                  child: _HiddenScrollbar(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Active priority sections
                        ..._buildPrioritySections(activeTasks),
                        // Completed tasks section
                        if (completedTasks.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildCompletedSection(completedTasks),
                        ],
                      ],
                    ),
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

class _HiddenScrollbar extends StatelessWidget {
  const _HiddenScrollbar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    );
  }
}

class _DangerMenuItemContent extends StatefulWidget {
  const _DangerMenuItemContent({required this.label});

  final String label;

  @override
  State<_DangerMenuItemContent> createState() => _DangerMenuItemContentState();
}

class _DangerMenuItemContentState extends State<_DangerMenuItemContent> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _hovered ? CueColors.dangerBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 17,
              color: CueColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: CueColors.danger,
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

class _TickTickTaskCard extends StatefulWidget {
  const _TickTickTaskCard({
    required this.task,
    required this.store,
    required this.onOpen,
  });

  final CueTask task;
  final TaskStore store;
  final VoidCallback onOpen;

  @override
  State<_TickTickTaskCard> createState() => _TickTickTaskCardState();
}

class _TickTickTaskCardState extends State<_TickTickTaskCard> {
  bool _hovered = false;

  Color _priorityColor(int priority) {
    return switch (priority) {
      0 => CueColors.danger,
      1 => CueColors.orange,
      2 => CueColors.accent,
      _ => CueColors.border,
    };
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final priorityColor = _priorityColor(task.priority);
    final cardContent = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: CueColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? CueColors.strongBorder
                  : CueColors.border.withValues(alpha: 0.6),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => unawaited(widget.store.toggleComplete(task)),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: task.isCompleted
                        ? CueColors.secondary.withValues(alpha: 0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: task.isCompleted
                          ? Colors.transparent
                          : priorityColor,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: task.isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: task.isCompleted
                            ? CueColors.tertiary
                            : CueColors.primary,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (task.dueAt != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        formatShortMonthDay(context, task.dueAt!),
                        style: const TextStyle(
                          fontSize: 11,
                          color: CueColors.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<CueTask>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 276, child: cardContent),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: cardContent),
      child: cardContent,
    );
  }
}

class _AddGroupColumn extends StatefulWidget {
  const _AddGroupColumn({required this.store});

  final TaskStore store;

  @override
  State<_AddGroupColumn> createState() => _AddGroupColumnState();
}

class _AddGroupColumnState extends State<_AddGroupColumn> {
  bool _isEditing = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      widget.store.addGroup(name);
      _controller.clear();
    }
    setState(() => _isEditing = false);
  }

  void _cancel() {
    _controller.clear();
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
      return SizedBox(
        width: 240,
        child: Align(
          alignment: Alignment.topLeft,
          child: InkWell(
            onTap: () {
              setState(() => _isEditing = true);
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _focusNode.requestFocus(),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: CueColors.subtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: CueColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: CueColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.addGroup,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CueColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CueColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CueColors.accent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: context.l10n.enterGroupName,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _cancel,
                  child: Text(context.l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: CueColors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                  ),
                  child: Text(context.l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
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
  final BoardGroup group;
  final ValueChanged<CueTask> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final tasks = store.tasks.where((task) => task.deletedAt == null).toList();
    final today = store.today;
    final groups = group == BoardGroup.priority
        ? <(String, List<CueTask>)>[
            for (var priority = 0; priority < 4; priority++)
              (
                'P$priority',
                tasks.where((task) => task.priority == priority).toList(),
              ),
          ]
        : <(String, List<CueTask>)>[
            (
              context.l10n.today,
              tasks
                  .where(
                    (task) =>
                        task.dueAt != null &&
                        !TaskStore.dateOnly(task.dueAt!).isAfter(today),
                  )
                  .toList(),
            ),
            (
              context.l10n.upcoming,
              tasks
                  .where(
                    (task) =>
                        task.dueAt != null &&
                        TaskStore.dateOnly(task.dueAt!).isAfter(today),
                  )
                  .toList(),
            ),
            (
              context.l10n.noDueDate,
              tasks.where((task) => task.dueAt == null).toList(),
            ),
          ];
    for (final (_, items) in groups) {
      items.sort((a, b) {
        final due = (a.dueAt ?? DateTime(2099)).compareTo(
          b.dueAt ?? DateTime(2099),
        );
        return due != 0 ? due : a.sortOrder.compareTo(b.sortOrder);
      });
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = constraints.maxWidth < 820
            ? 300.0
            : (constraints.maxWidth - (groups.length - 1) * 16) / groups.length;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              maxHeight: constraints.maxHeight,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < groups.length; index++) ...[
                  if (index > 0) const SizedBox(width: 16),
                  Container(
                    width: columnWidth,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CueColors.subtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${groups[index].$1} · ${groups[index].$2.length}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: CueColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _HiddenScrollbar(
                            child: ListView.separated(
                              itemCount: groups[index].$2.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, taskIndex) {
                                final task = groups[index].$2[taskIndex];
                                return CueTaskCard(
                                  task: task,
                                  referenceDate: store.today,
                                  onOpen: () => onOpenTask(task),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
