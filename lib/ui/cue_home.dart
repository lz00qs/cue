import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/task_store.dart';
import '../models/cue_task.dart';
import 'cue_theme.dart';
import 'cue_widgets.dart';
import 'views/board_view.dart';
import 'views/calendar_view.dart';
import 'views/quadrants_view.dart';

enum CueView { inbox, today, upcoming, list, board, calendar, quadrants }

enum CueListFilter { today, upcoming, completed }

class CueHome extends StatefulWidget {
  const CueHome({
    super.key,
    required this.store,
    this.userEmail,
    this.onLogout,
  });

  final TaskStore store;
  final String? userEmail;
  final Future<void> Function()? onLogout;

  @override
  State<CueHome> createState() => _CueHomeState();
}

class _CueHomeState extends State<CueHome> {
  CueView _view = CueView.today;
  CueListFilter _listFilter = CueListFilter.today;
  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();

  @override
  void dispose() {
    _quickAddController.dispose();
    _quickAddFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyK, meta: true):
                _FocusQuickAddIntent(),
            SingleActivator(LogicalKeyboardKey.keyK, control: true):
                _FocusQuickAddIntent(),
          },
          child: Actions(
            actions: {
              _FocusQuickAddIntent: CallbackAction<_FocusQuickAddIntent>(
                onInvoke: (_) {
                  setState(() {
                    _view = CueView.today;
                    _listFilter = CueListFilter.today;
                  });
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _quickAddFocus.requestFocus(),
                  );
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 840) return _buildMobile();
                  return _buildDesktop();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: _view == CueView.quadrants
          ? CueColors.subtle
          : CueColors.canvas,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            selected: _view,
            onSelect: _selectView,
            userEmail: widget.userEmail,
            onLogout: widget.onLogout,
          ),
          Expanded(child: _buildContent(desktop: true)),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    final mobileIndex = switch (_view) {
      CueView.board => 1,
      CueView.calendar => 2,
      CueView.quadrants => 3,
      _ => 0,
    };
    return Scaffold(
      backgroundColor: _view == CueView.quadrants
          ? CueColors.subtle
          : CueColors.canvas,
      appBar: AppBar(
        backgroundColor: _view == CueView.quadrants
            ? CueColors.subtle
            : CueColors.canvas,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cue',
              style: TextStyle(
                color: CueColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Move what’s next',
              style: TextStyle(
                color: CueColors.tertiary,
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.onLogout != null)
            IconButton(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              tooltip: 'Sign out',
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filled(
              onPressed: () => _showAddTaskDialog(),
              icon: const Icon(Icons.add, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: CueColors.accent,
                foregroundColor: Colors.white,
              ),
              tooltip: 'Add task',
            ),
          ),
        ],
      ),
      body: _buildContent(desktop: false),
      bottomNavigationBar: NavigationBar(
        height: 68,
        selectedIndex: mobileIndex,
        indicatorColor: CueColors.selected,
        backgroundColor: CueColors.canvas,
        surfaceTintColor: Colors.transparent,
        onDestinationSelected: (index) {
          _selectView(
            [
              CueView.today,
              CueView.board,
              CueView.calendar,
              CueView.quadrants,
            ][index],
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined),
            label: 'Board',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Quadrants',
          ),
        ],
      ),
    );
  }

  Widget _buildContent({required bool desktop}) {
    final horizontalPadding = desktop
        ? (_view == CueView.today ||
                  _view == CueView.inbox ||
                  _view == CueView.list
              ? 40.0
              : 48.0)
        : 20.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                desktop ? 40 : 20,
                horizontalPadding,
                48,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageHeader(
                    title: _pageTitle,
                    subtitle: _pageSubtitle,
                    actionLabel: _view == CueView.calendar
                        ? 'Today'
                        : 'Add task',
                    onAction: _view == CueView.calendar
                        ? () => _selectView(CueView.today)
                        : () => _showAddTaskDialog(),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: KeyedSubtree(key: ValueKey(_view), child: _pageBody),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _pageTitle => switch (_view) {
    CueView.inbox => 'Inbox',
    CueView.today => 'Today',
    CueView.upcoming => 'Upcoming',
    CueView.list => 'All tasks',
    CueView.board => 'Board',
    CueView.calendar =>
      '${_monthNames[widget.store.today.month - 1]} ${widget.store.today.year}',
    CueView.quadrants => 'Quadrants',
  };

  String get _pageSubtitle => switch (_view) {
    CueView.inbox => '${widget.store.activeTasks.length} open tasks',
    CueView.today =>
      '${_weekdayNames[widget.store.today.weekday - 1]}, ${_monthNames[widget.store.today.month - 1]} ${widget.store.today.day} · ${widget.store.todayTasks.length} tasks',
    CueView.upcoming => 'Plan what comes next',
    CueView.list => 'One task model, every active item',
    CueView.board => 'Three focused stages, one task model',
    CueView.calendar => 'Month view · Due dates only',
    CueView.quadrants => 'Importance × urgency · urgency within 2 days',
  };

  Widget get _pageBody => switch (_view) {
    CueView.board => BoardView(
      store: widget.store,
      onOpenTask: _showTaskDetails,
    ),
    CueView.calendar => CalendarView(
      store: widget.store,
      onOpenTask: _showTaskDetails,
      onSelectDay: (day) => _showAddTaskDialog(prefilledDate: day),
    ),
    CueView.quadrants => QuadrantsView(
      store: widget.store,
      onOpenTask: _showTaskDetails,
    ),
    _ => _TaskListView(
      store: widget.store,
      view: _view,
      filter: _listFilter,
      quickAddController: _quickAddController,
      quickAddFocus: _quickAddFocus,
      onFilterChanged: (filter) => setState(() => _listFilter = filter),
      onQuickAdd: _quickAdd,
      onOpenTask: _showTaskDetails,
    ),
  };

  void _selectView(CueView view) {
    setState(() {
      _view = view;
      if (view == CueView.today) _listFilter = CueListFilter.today;
      if (view == CueView.upcoming) _listFilter = CueListFilter.upcoming;
    });
  }

  Future<void> _quickAdd() async {
    final title = _quickAddController.text;
    if (title.trim().isEmpty) {
      _quickAddFocus.requestFocus();
      return;
    }
    final today = widget.store.today;
    final succeeded = await _runTaskOperation(
      () => widget.store.addTask(
        title: title,
        dueAt: DateTime(today.year, today.month, today.day, 18),
      ),
    );
    if (succeeded && mounted) {
      _quickAddController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task added to Today'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showAddTaskDialog({DateTime? prefilledDate}) async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    var priority = 2;
    var important = false;
    var status = CueTaskStatus.todo;
    final today = widget.store.today;
    DateTime? dueAt = prefilledDate == null
        ? DateTime(today.year, today.month, today.day, 18)
        : DateTime(
            prefilledDate.year,
            prefilledDate.month,
            prefilledDate.day,
            18,
          );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              title: const Text(
                'New task',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: CueColors.primary,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: titleController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Task title',
                          hintText: 'What needs to move next?',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Note'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: priority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                              ),
                              items: List.generate(
                                4,
                                (index) => DropdownMenuItem(
                                  value: index,
                                  child: Text('P$index'),
                                ),
                              ),
                              onChanged: (value) =>
                                  setModalState(() => priority = value ?? 2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<CueTaskStatus>(
                              initialValue: status,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: CueTaskStatus.todo,
                                  child: Text('To do'),
                                ),
                                DropdownMenuItem(
                                  value: CueTaskStatus.doing,
                                  child: Text('Doing'),
                                ),
                                DropdownMenuItem(
                                  value: CueTaskStatus.done,
                                  child: Text('Done'),
                                ),
                              ],
                              onChanged: (value) => setModalState(
                                () => status = value ?? CueTaskStatus.todo,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DateTime?>(
                        initialValue: dueAt,
                        decoration: const InputDecoration(
                          labelText: 'Due date',
                        ),
                        items: _dueDateChoices(dueAt),
                        onChanged: (value) =>
                            setModalState(() => dueAt = value),
                      ),
                      const SizedBox(height: 6),
                      CheckboxListTile(
                        value: important,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text('Important'),
                        subtitle: const Text('Used by the quadrant view'),
                        onChanged: (value) =>
                            setModalState(() => important = value ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    final succeeded = await _runTaskOperation(
                      () => widget.store.addTask(
                        title: titleController.text,
                        note: noteController.text,
                        priority: priority,
                        important: important,
                        status: status,
                        dueAt: dueAt,
                      ),
                    );
                    if (succeeded && dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: CueColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add task'),
                ),
              ],
            );
          },
        );
      },
    );
    titleController.dispose();
    noteController.dispose();
  }

  Future<void> _showTaskDetails(CueTask initialTask) async {
    var task = initialTask;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(24),
              content: SizedBox(
                width: 392,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: const TextStyle(
                              color: CueColors.primary,
                              fontSize: 22,
                              height: 28 / 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.note.isEmpty
                          ? 'A focused next action in your Cue workspace.'
                          : task.note,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    _DetailLine(
                      label: 'Due',
                      value: cueDueLabel(task).replaceFirst('Due ', ''),
                    ),
                    const SizedBox(height: 12),
                    _DetailLine(label: 'Priority', value: 'P${task.priority}'),
                    const SizedBox(height: 12),
                    _DetailLine(
                      label: 'Status',
                      value: switch (task.status) {
                        CueTaskStatus.todo => 'To do',
                        CueTaskStatus.doing => 'Doing',
                        CueTaskStatus.done => 'Done',
                      },
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: task.important,
                      activeTrackColor: CueColors.accent,
                      title: const Text('Important'),
                      subtitle: const Text('Controls the quadrant projection'),
                      onChanged: (_) async {
                        final succeeded = await _runTaskOperation(
                          () => widget.store.toggleImportant(task),
                        );
                        if (!succeeded || !dialogContext.mounted) return;
                        task = widget.store.tasks.firstWhere(
                          (item) => item.id == task.id,
                        );
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final succeeded = await _runTaskOperation(
                                () => widget.store.moveToStatus(
                                  task,
                                  CueTaskStatus.doing,
                                ),
                              );
                              if (succeeded && dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: CueColors.primary,
                              side: const BorderSide(color: CueColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Move to Doing'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final succeeded = await _runTaskOperation(
                                () => widget.store.toggleComplete(task),
                              );
                              if (succeeded && dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: CueColors.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              task.isCompleted ? 'Reopen' : 'Complete',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton.icon(
                        onPressed: () async {
                          final confirmed = await _confirmDelete(task);
                          if (!confirmed || !dialogContext.mounted) return;
                          final succeeded = await _runTaskOperation(
                            () => widget.store.deleteTask(task),
                          );
                          if (succeeded && dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete task'),
                        style: TextButton.styleFrom(
                          foregroundColor: CueColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDelete(CueTask task) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete task?'),
            content: Text(
              '“${task.title}” will be removed from every view. '
              'The server keeps a sync tombstone so other sessions can apply the deletion.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: CueColors.danger,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  List<DropdownMenuItem<DateTime?>> _dueDateChoices(DateTime? selected) {
    final today = widget.store.today;
    final values = <DateTime?>[
      DateTime(today.year, today.month, today.day, 18),
      DateTime(today.year, today.month, today.day + 1, 18),
      selected,
      null,
    ];
    final seen = <int?>{};
    return values.where((value) => seen.add(value?.millisecondsSinceEpoch)).map(
      (value) {
        final label = value == null
            ? 'No due date'
            : TaskStore.isSameDay(value, today)
            ? 'Today · 18:00'
            : TaskStore.isSameDay(value, today.add(const Duration(days: 1)))
            ? 'Tomorrow · 18:00'
            : '${_monthNames[value.month - 1]} ${value.day} · 18:00';
        return DropdownMenuItem(value: value, child: Text(label));
      },
    ).toList();
  }

  Future<bool> _runTaskOperation(Future<void> Function() operation) async {
    try {
      await operation();
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: CueColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
}

class _FocusQuickAddIntent extends Intent {
  const _FocusQuickAddIntent();
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.userEmail,
    required this.onLogout,
  });

  final CueView selected;
  final ValueChanged<CueView> onSelect;
  final String? userEmail;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      padding: const EdgeInsets.fromLTRB(16, 28, 4, 24),
      decoration: const BoxDecoration(
        color: CueColors.sidebar,
        border: Border(right: BorderSide(color: CueColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cue',
            style: TextStyle(
              color: CueColors.primary,
              fontSize: 24,
              height: 29 / 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Move what’s next',
            style: TextStyle(
              color: CueColors.tertiary,
              fontSize: 11,
              height: 13 / 11,
            ),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: 'Inbox',
            selected: selected == CueView.inbox,
            onTap: () => onSelect(CueView.inbox),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: 'Today',
            selected: selected == CueView.today,
            onTap: () => onSelect(CueView.today),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: 'Upcoming',
            selected: selected == CueView.upcoming,
            onTap: () => onSelect(CueView.upcoming),
          ),
          const SizedBox(height: 8),
          const SizedBox(
            width: 220,
            child: Divider(height: 1, thickness: 1, color: CueColors.border),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: 'List',
            selected: selected == CueView.list,
            onTap: () => onSelect(CueView.list),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: 'Board',
            selected: selected == CueView.board,
            onTap: () => onSelect(CueView.board),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: 'Calendar',
            selected: selected == CueView.calendar,
            onTap: () => onSelect(CueView.calendar),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: 'Quadrants',
            selected: selected == CueView.quadrants,
            onTap: () => onSelect(CueView.quadrants),
          ),
          const Spacer(),
          Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: CueColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    userEmail == null ? 'Synced' : '$userEmail · Synced',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CueColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (onLogout != null)
                  IconButton(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Sign out',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 232,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? CueColors.selected
                : _hovered
                ? const Color(0xFFEDEEF2)
                : CueColors.sidebar,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                widget.selected
                    ? 'assets/figma/indicator-selected.svg'
                    : 'assets/figma/indicator.svg',
                width: 8,
                height: 8,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.selected ? CueColors.accent : CueColors.primary,
                  fontSize: 15,
                  height: 21 / 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CueActionButton(
            label: actionLabel,
            primary: actionLabel != 'Today',
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

class _TaskListView extends StatelessWidget {
  const _TaskListView({
    required this.store,
    required this.view,
    required this.filter,
    required this.quickAddController,
    required this.quickAddFocus,
    required this.onFilterChanged,
    required this.onQuickAdd,
    required this.onOpenTask,
  });

  final TaskStore store;
  final CueView view;
  final CueListFilter filter;
  final TextEditingController quickAddController;
  final FocusNode quickAddFocus;
  final ValueChanged<CueListFilter> onFilterChanged;
  final VoidCallback onQuickAdd;
  final ValueChanged<CueTask> onOpenTask;

  @override
  Widget build(BuildContext context) {
    final tasks = switch (view) {
      CueView.inbox => store.activeTasks.toList(),
      CueView.upcoming => store.upcomingTasks,
      CueView.list =>
        store.tasks.where((task) => task.deletedAt == null).toList(),
      _ => switch (filter) {
        CueListFilter.today => store.todayTasks,
        CueListFilter.upcoming => store.upcomingTasks,
        CueListFilter.completed => store.completedTasks.toList(),
      },
    };
    final showFilters = view == CueView.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuickCapture(
          controller: quickAddController,
          focusNode: quickAddFocus,
          onAdd: onQuickAdd,
        ),
        const SizedBox(height: 24),
        if (showFilters) ...[
          SizedBox(
            height: 44,
            child: Row(
              children: [
                CueViewTab(
                  label: 'Today',
                  selected: filter == CueListFilter.today,
                  onTap: () => onFilterChanged(CueListFilter.today),
                ),
                const SizedBox(width: 8),
                CueViewTab(
                  label: 'Upcoming',
                  selected: filter == CueListFilter.upcoming,
                  onTap: () => onFilterChanged(CueListFilter.upcoming),
                ),
                const SizedBox(width: 8),
                CueViewTab(
                  label: 'Completed',
                  selected: filter == CueListFilter.completed,
                  onTap: () => onFilterChanged(CueListFilter.completed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          view == CueView.today
              ? 'Focus for today'
              : _sectionTitle(view, tasks.length),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: CueColors.secondary),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const _EmptyTaskList()
        else
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CueTaskRow(
                key: ValueKey(task.id),
                task: task,
                metaOverride:
                    view == CueView.today &&
                        filter == CueListFilter.today &&
                        task.id == 'lab-calibration'
                    ? 'No time · Operations'
                    : null,
                onToggle: () async {
                  try {
                    await store.toggleComplete(task);
                  } catch (_) {
                    // The store rolls the optimistic change back on failure.
                  }
                },
                onOpen: () => onOpenTask(task),
              ),
            ),
          ),
      ],
    );
  }

  static String _sectionTitle(CueView view, int count) => switch (view) {
    CueView.inbox => 'Open tasks · $count',
    CueView.upcoming => 'Coming up · $count',
    CueView.list => 'All tasks · $count',
    _ => 'Tasks · $count',
  };
}

class _QuickCapture extends StatelessWidget {
  const _QuickCapture({
    required this.controller,
    required this.focusNode,
    required this.onAdd,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: BoxDecoration(
        color: CueColors.canvas,
        border: Border.all(color: CueColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SvgPicture.asset('assets/figma/plus.svg', width: 20, height: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('quick-add-field'),
              controller: controller,
              focusNode: focusNode,
              onSubmitted: (_) => onAdd(),
              style: const TextStyle(
                color: CueColors.primary,
                fontSize: 13,
                height: 18 / 13,
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Add a task…  try “PCB review tomorrow 10:30”',
                hintStyle: TextStyle(color: CueColors.tertiary),
              ),
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 720) ...[
            const Text(
              '⌘ K',
              style: TextStyle(
                color: CueColors.tertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
          ],
          CueActionButton(label: 'Add', onPressed: onAdd),
        ],
      ),
    );
  }
}

class _EmptyTaskList extends StatelessWidget {
  const _EmptyTaskList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CueColors.subtle,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Nothing here — enjoy the space.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: CueColors.tertiary),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
