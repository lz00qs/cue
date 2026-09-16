import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/task_store.dart';
import '../data/sync_coordinator.dart';
import '../l10n/l10n.dart';
import '../models/cue_task.dart';
import 'cue_theme.dart';
import 'cue_widgets.dart';
import 'desktop/task_details_popover.dart';
import 'language_menu.dart';
import 'mobile/mobile_cue_home.dart';
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
    this.serverUrl,
    this.onConfigureServer,
  });

  final TaskStore store;
  final String? userEmail;
  final Future<void> Function()? onLogout;
  final String? serverUrl;
  final VoidCallback? onConfigureServer;

  @override
  State<CueHome> createState() => _CueHomeState();
}

class _CueHomeState extends State<CueHome> with WidgetsBindingObserver {
  CueView _view = CueView.today;
  CueListFilter _listFilter = CueListFilter.today;
  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();
  late final SyncCoordinator _syncCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncCoordinator = SyncCoordinator(widget.store)..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncCoordinator.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _syncCoordinator.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncCoordinator.dispose();
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
            store: widget.store,
            selected: _view,
            onSelect: _selectView,
            userEmail: widget.userEmail,
            onLogout: widget.onLogout,
            serverUrl: widget.serverUrl,
            onConfigureServer: widget.onConfigureServer,
            onSync: () => _runTaskOperation(widget.store.sync),
          ),
          Expanded(child: _buildContent(desktop: true)),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return MobileCueHome(
      store: widget.store,
      userEmail: widget.userEmail,
      onLogout: widget.onLogout,
      serverUrl: widget.serverUrl,
      onConfigureServer: widget.onConfigureServer,
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
                        ? context.l10n.today
                        : context.l10n.addTask,
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
    CueView.inbox => context.l10n.inbox,
    CueView.today => context.l10n.today,
    CueView.upcoming => context.l10n.upcoming,
    CueView.list => context.l10n.allTasks,
    CueView.board => context.l10n.board,
    CueView.calendar => formatMonthYear(context, widget.store.today),
    CueView.quadrants => context.l10n.quadrants,
  };

  String get _pageSubtitle => switch (_view) {
    CueView.inbox => context.l10n.openTaskCount(
      widget.store.activeTasks.length,
    ),
    CueView.today =>
      '${formatLongDate(context, widget.store.today)} · ${context.l10n.taskCount(widget.store.todayTasks.length)}',
    CueView.upcoming => context.l10n.planWhatComesNext,
    CueView.list => context.l10n.oneTaskModel,
    CueView.board => context.l10n.threeStages,
    CueView.calendar => context.l10n.monthViewDueOnly,
    CueView.quadrants => context.l10n.importanceUrgencyTwoDays,
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
        SnackBar(
          content: Text(context.l10n.taskAddedToday),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
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
              title: Text(
                context.l10n.newTask,
                style: const TextStyle(
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
                        decoration: InputDecoration(
                          labelText: context.l10n.taskTitle,
                          hintText: context.l10n.taskTitleHint,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: context.l10n.note,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: priority,
                              decoration: InputDecoration(
                                labelText: context.l10n.priority,
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
                              decoration: InputDecoration(
                                labelText: context.l10n.status,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: CueTaskStatus.todo,
                                  child: Text(context.l10n.toDo),
                                ),
                                DropdownMenuItem(
                                  value: CueTaskStatus.doing,
                                  child: Text(context.l10n.doing),
                                ),
                                DropdownMenuItem(
                                  value: CueTaskStatus.done,
                                  child: Text(context.l10n.done),
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
                        decoration: InputDecoration(
                          labelText: context.l10n.dueDate,
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
                        title: Text(context.l10n.important),
                        subtitle: Text(context.l10n.quadrantUsage),
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
                  child: Text(context.l10n.cancel),
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
                  child: Text(context.l10n.addTask),
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
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => TaskDetailsPopover(
        initialTask: initialTask,
        store: widget.store,
        onRun: _runTaskOperation,
        onClose: () => Navigator.pop(dialogContext),
        onDelete: (task) async {
          final confirmed = await _confirmDelete(task);
          if (!confirmed || !dialogContext.mounted) return;
          final succeeded = await _runTaskOperation(
            () => widget.store.deleteTask(task),
          );
          if (succeeded && dialogContext.mounted) Navigator.pop(dialogContext);
        },
      ),
    );
  }

  Future<bool> _confirmDelete(CueTask task) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.deleteTaskQuestion),
            content: Text(context.l10n.deleteTaskExplanation(task.title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: CueColors.danger,
                ),
                child: Text(context.l10n.delete),
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
            ? context.l10n.noDueDate
            : TaskStore.isSameDay(value, today)
            ? '${context.l10n.today} · 18:00'
            : TaskStore.isSameDay(value, today.add(const Duration(days: 1)))
            ? '${context.l10n.tomorrow} · 18:00'
            : '${formatShortMonthDay(context, value)} · 18:00';
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
}

class _FocusQuickAddIntent extends Intent {
  const _FocusQuickAddIntent();
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.store,
    required this.selected,
    required this.onSelect,
    required this.userEmail,
    required this.onLogout,
    required this.serverUrl,
    required this.onConfigureServer,
    required this.onSync,
  });

  final TaskStore store;
  final CueView selected;
  final ValueChanged<CueView> onSelect;
  final String? userEmail;
  final Future<void> Function()? onLogout;
  final String? serverUrl;
  final VoidCallback? onConfigureServer;
  final Future<bool> Function() onSync;

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
          const SizedBox(height: 8),
          Text(
            context.l10n.tagline,
            style: const TextStyle(
              color: CueColors.tertiary,
              fontSize: 11,
              height: 13 / 11,
            ),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: context.l10n.inbox,
            selected: selected == CueView.inbox,
            onTap: () => onSelect(CueView.inbox),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: context.l10n.today,
            selected: selected == CueView.today,
            onTap: () => onSelect(CueView.today),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: context.l10n.upcoming,
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
            label: context.l10n.list,
            selected: selected == CueView.list,
            onTap: () => onSelect(CueView.list),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: context.l10n.board,
            selected: selected == CueView.board,
            onTap: () => onSelect(CueView.board),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: context.l10n.calendar,
            selected: selected == CueView.calendar,
            onTap: () => onSelect(CueView.calendar),
          ),
          const SizedBox(height: 8),
          _SidebarItem(
            label: context.l10n.quadrants,
            selected: selected == CueView.quadrants,
            onTap: () => onSelect(CueView.quadrants),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: LanguageMenuButton(showLabel: true),
          ),
          if (serverUrl != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
              child: Text(
                serverUrl!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: CueColors.tertiary, fontSize: 11),
              ),
            ),
          Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CueColors.card.withValues(alpha: 0.64),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: store.lastError == null
                        ? CueColors.green
                        : CueColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    store.lastError ??
                        (store.isSyncing
                            ? context.l10n.syncing
                            : userEmail == null
                            ? context.l10n.synced
                            : context.l10n.userSynced(userEmail!)),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CueColors.secondary,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (store.isRemote)
                  IconButton(
                    onPressed: store.isSyncing ? null : onSync,
                    icon: const Icon(Icons.sync_rounded, size: 17),
                    visualDensity: VisualDensity.compact,
                    tooltip: context.l10n.syncNow,
                  ),
                if (onConfigureServer != null)
                  IconButton(
                    onPressed: onConfigureServer,
                    icon: const Icon(Icons.dns_outlined, size: 17),
                    visualDensity: VisualDensity.compact,
                    tooltip: context.l10n.changeServer,
                  ),
                if (onLogout != null)
                  IconButton(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: context.l10n.signOut,
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
                ? CueColors.sidebarHover
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
                colorFilter: ColorFilter.mode(
                  widget.selected ? CueColors.accent : CueColors.secondary,
                  BlendMode.srcIn,
                ),
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
            primary: actionLabel != context.l10n.today,
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
                  label: context.l10n.today,
                  selected: filter == CueListFilter.today,
                  onTap: () => onFilterChanged(CueListFilter.today),
                ),
                const SizedBox(width: 8),
                CueViewTab(
                  label: context.l10n.upcoming,
                  selected: filter == CueListFilter.upcoming,
                  onTap: () => onFilterChanged(CueListFilter.upcoming),
                ),
                const SizedBox(width: 8),
                CueViewTab(
                  label: context.l10n.completed,
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
              ? context.l10n.focusForToday
              : _sectionTitle(context, view, tasks.length),
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
                referenceDate: store.today,
                metaOverride:
                    view == CueView.today &&
                        filter == CueListFilter.today &&
                        task.id == 'lab-calibration'
                    ? '${context.l10n.noTime} · ${context.l10n.operations}'
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

  static String _sectionTitle(BuildContext context, CueView view, int count) =>
      switch (view) {
        CueView.inbox => context.l10n.openTasksLabel(count),
        CueView.upcoming => context.l10n.comingUpLabel(count),
        CueView.list => context.l10n.allTasksLabel(count),
        _ => context.l10n.tasksLabel(count),
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
        color: CueColors.card,
        border: Border.all(color: CueColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/figma/plus.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              CueColors.accent,
              BlendMode.srcIn,
            ),
          ),
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
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: context.l10n.quickAddHint,
                hintStyle: const TextStyle(color: CueColors.tertiary),
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
          CueActionButton(label: context.l10n.add, onPressed: onAdd),
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
        context.l10n.emptyList,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: CueColors.tertiary),
      ),
    );
  }
}
