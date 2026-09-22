import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/task_store.dart';
import '../state/app_state.dart';
import '../state/page_state.dart';
import '../data/sync_coordinator.dart';
import '../l10n/l10n.dart';
import '../models/cue_task.dart';
import 'cue_theme.dart';
import 'appearance_menu.dart';
import 'cue_date_picker.dart';
import 'cue_widgets.dart';
import 'desktop/task_details_popover.dart';
import 'language_menu.dart';
import 'mobile/mobile_cue_home.dart';
import 'views/board_view.dart';
import 'views/calendar_view.dart';
import 'views/quadrants_view.dart';

class CueHome extends ConsumerStatefulWidget {
  const CueHome({
    super.key,
    this.userEmail,
    this.onLogout,
    this.serverUrl,
    this.onConfigureServer,
  });

  final String? userEmail;
  final Future<void> Function()? onLogout;
  final String? serverUrl;
  final VoidCallback? onConfigureServer;

  @override
  ConsumerState<CueHome> createState() => _CueHomeState();
}

class _CueHomeState extends ConsumerState<CueHome> with WidgetsBindingObserver {
  TaskStore get _store => ref.read(taskStoreProvider)!;
  CueView get _view => ref.read(cueHomeUiProvider).view;
  CueListFilter get _listFilter => ref.read(cueHomeUiProvider).filter;
  final _quickAddController = TextEditingController();
  final _quickAddFocus = FocusNode();
  late final SyncCoordinator _syncCoordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncCoordinator = SyncCoordinator(_store)..start();
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
    ref.watch(taskRevisionProvider);
    ref.watch(cueHomeUiProvider);
    ref.watch(mobileUiProvider);
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
              ref.read(cueHomeUiProvider.notifier).focusToday();
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
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: CueColors.canvas,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            store: _store,
            selected: _view,
            onSelect: _selectView,
            userEmail: widget.userEmail,
            onLogout: widget.onLogout,
            serverUrl: widget.serverUrl,
            onConfigureServer: widget.onConfigureServer,
            onSync: () => _runTaskOperation(_store.sync),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    return MobileCueHome(
      userEmail: widget.userEmail,
      onLogout: widget.onLogout,
      serverUrl: widget.serverUrl,
      onConfigureServer: widget.onConfigureServer,
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_view == CueView.calendar ||
            _view == CueView.inbox ||
            _view == CueView.board) {
          return Padding(
            key: const Key('desktop-page-padding'),
            padding: CueInsets.desktopFixedPage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PageHeader(
                  title: _pageTitle,
                  subtitle: _pageSubtitle,
                  onTitleTap: _view == CueView.calendar
                      ? _showMonthPickerPopover
                      : null,
                  extraActions: _view == CueView.calendar
                      ? const _CalendarMonthHeaderNavigation()
                      : null,
                  actionLabel: context.l10n.addTask,
                  onAction: () => _showAddTaskDialog(),
                  useIconButton: true,
                  showAction: _view == CueView.calendar,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    layoutBuilder: _topAlignedSwitcherLayout,
                    child: KeyedSubtree(key: ValueKey(_view), child: _pageBody),
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              key: const Key('desktop-page-padding'),
              padding: CueInsets.desktopScrollablePage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageHeader(
                    title: _pageTitle,
                    subtitle: _pageSubtitle,
                    onTitleTap: _view == CueView.calendar
                        ? _showMonthPickerPopover
                        : null,
                    extraActions: _view == CueView.calendar
                        ? const _CalendarMonthHeaderNavigation()
                        : null,
                    actionLabel: context.l10n.addTask,
                    onAction: () => _showAddTaskDialog(),
                    showAction: _view == CueView.quadrants,
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    layoutBuilder: _topAlignedSwitcherLayout,
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
    CueView.board => context.l10n.inbox,
    CueView.calendar => formatMonthYear(
      context,
      ref.watch(calendarFocusedMonthProvider),
    ),
    CueView.quadrants => context.l10n.quadrants,
  };

  String get _pageSubtitle => switch (_view) {
    CueView.inbox => context.l10n.openTaskCount(_store.activeTasks.length),
    CueView.today =>
      '${formatLongDate(context, _store.today)} · ${context.l10n.taskCount(_store.todayTasks.length)}',
    CueView.upcoming => context.l10n.planWhatComesNext,
    CueView.list => context.l10n.oneTaskModel,
    CueView.board => context.l10n.openTaskCount(_store.activeTasks.length),
    CueView.calendar => context.l10n.monthViewDueOnly,
    CueView.quadrants => context.l10n.importanceUrgencyTwoDays,
  };

  Widget get _pageBody => switch (_view) {
    CueView.inbox || CueView.board => BoardView(
      onOpenTask: _showTaskDetails,
      onAddTask: ({group, priority}) => _showAddTaskDialog(
        prefilledGroup: group,
        prefilledPriority: priority,
      ),
    ),
    CueView.calendar => CalendarView(
      onOpenTask: _showTaskDetails,
      onSelectDay: (day) => _showAddTaskDialog(prefilledDate: day),
    ),
    CueView.quadrants => QuadrantsView(onOpenTask: _showTaskDetails),
    _ => _TaskListView(
      store: _store,
      view: _view,
      filter: _listFilter,
      quickAddController: _quickAddController,
      quickAddFocus: _quickAddFocus,
      onFilterChanged: (filter) =>
          ref.read(cueHomeUiProvider.notifier).selectFilter(filter),
      onQuickAdd: _quickAdd,
      onOpenTask: _showTaskDetails,
    ),
  };

  void _selectView(CueView view) {
    ref.read(cueHomeUiProvider.notifier).selectView(view);
  }

  Future<void> _quickAdd() async {
    final title = _quickAddController.text;
    if (title.trim().isEmpty) {
      _quickAddFocus.requestFocus();
      return;
    }
    final today = _store.today;
    final succeeded = await _runTaskOperation(
      () => _store.addTask(
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

  Future<void> _showMonthPickerPopover() async {
    await showDialog<void>(
      context: context,
      barrierColor: CueColors.modalBarrier,
      builder: (dialogContext) => const MonthPickerPopover(),
    );
  }

  Future<void> _showAddTaskDialog({
    DateTime? prefilledDate,
    String? prefilledGroup,
    int? prefilledPriority,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddTaskDialog(
        store: _store,
        onRunOperation: _runTaskOperation,
        prefilledDate: prefilledDate,
        prefilledGroup: prefilledGroup,
        prefilledPriority: prefilledPriority,
      ),
    );
  }

  Future<void> _showTaskDetails(CueTask initialTask) async {
    await showDialog<void>(
      context: context,
      barrierColor: CueColors.modalBarrier,
      builder: (dialogContext) => TaskDetailsPopover(
        initialTask: initialTask,
        onRun: _runTaskOperation,
        onClose: () => Navigator.pop(dialogContext),
        onDelete: (task) async {
          final confirmed = await _confirmDelete(task);
          if (!confirmed || !dialogContext.mounted) return;
          final succeeded = await _runTaskOperation(
            () => _store.deleteTask(task),
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

Widget _topAlignedSwitcherLayout(
  Widget? currentChild,
  List<Widget> previousChildren,
) {
  return Stack(
    alignment: Alignment.topCenter,
    children: [...previousChildren, ?currentChild],
  );
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
      padding: const EdgeInsets.fromLTRB(
        CueSpacing.s16,
        CueSpacing.s16,
        CueSpacing.s4,
        CueSpacing.s24,
      ),
      decoration: BoxDecoration(
        color: CueColors.sidebar,
        border: Border(right: BorderSide(color: CueColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
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
            count: store.activeTasks.length,
            selected: selected == CueView.inbox || selected == CueView.board,
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
          SizedBox(
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
            padding: EdgeInsets.only(
              left: CueSpacing.s4,
              bottom: CueSpacing.s8,
            ),
            child: AppearanceMenuButton(showLabel: true),
          ),
          const Padding(
            padding: EdgeInsets.only(
              left: CueSpacing.s4,
              bottom: CueSpacing.s8,
            ),
            child: LanguageMenuButton(showLabel: true),
          ),
          if (serverUrl != null)
            Padding(
              padding: const EdgeInsets.only(
                left: CueSpacing.s12,
                right: CueSpacing.s12,
                bottom: CueSpacing.s8,
              ),
              child: Text(
                serverUrl!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: CueColors.tertiary, fontSize: 11),
              ),
            ),
          Container(
            width: 220,
            padding: CueInsets.card,
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
                    style: TextStyle(color: CueColors.secondary, fontSize: 11),
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
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

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
          padding: const EdgeInsets.symmetric(horizontal: CueSpacing.s12),
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
              Expanded(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.selected
                        ? CueColors.accent
                        : CueColors.primary,
                    fontSize: 15,
                    height: 21 / 15,
                  ),
                ),
              ),
              if (widget.count != null && widget.count! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CueSpacing.s8,
                    vertical: CueSpacing.s2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? CueColors.accent.withValues(alpha: 0.15)
                        : (CueColors.border.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      color: widget.selected
                          ? CueColors.accent
                          : CueColors.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
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
    this.extraActions,
    this.onTitleTap,
    this.useIconButton = false,
    this.showAction = true,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? extraActions;
  final VoidCallback? onTitleTap;
  final bool useIconButton;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 68),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onTitleTap != null)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: const Key('calendar-title-picker-trigger'),
                      onTap: onTitleTap,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: CueColors.secondary,
                          ),
                        ],
                      ),
                    ),
                  )
                else
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
          if (extraActions != null) ...[
            extraActions!,
            const SizedBox(width: 12),
          ],
          if (showAction && useIconButton)
            SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                key: const Key('calendar-add-task-button'),
                style: IconButton.styleFrom(
                  backgroundColor: CueColors.accent,
                  foregroundColor: CueColors.onAccent,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                onPressed: onAction,
                tooltip: actionLabel,
              ),
            )
          else if (showAction)
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

class _CalendarMonthHeaderNavigation extends ConsumerWidget {
  const _CalendarMonthHeaderNavigation();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dueOnly = ref.watch(calendarDueOnlyProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CueViewTab(
          label: context.l10n.dueOnly,
          selected: dueOnly,
          onTap: () => ref.read(calendarDueOnlyProvider.notifier).toggle(),
        ),
        const SizedBox(width: 12),
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: CueColors.subtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CueColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('calendar-prev-month'),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: CueColors.primary,
                ),
                onPressed: () => ref
                    .read(calendarFocusedMonthProvider.notifier)
                    .previousMonth(),
                tooltip: context.l10n.month,
              ),
              Container(width: 1, height: 16, color: CueColors.border),
              InkWell(
                key: const Key('calendar-today-button'),
                onTap: () => ref
                    .read(calendarFocusedMonthProvider.notifier)
                    .resetToToday(),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CueSpacing.s10,
                  ),
                  child: Text(
                    context.l10n.today,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: CueColors.primary,
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 16, color: CueColors.border),
              IconButton(
                key: const Key('calendar-next-month'),
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  color: CueColors.primary,
                ),
                onPressed: () =>
                    ref.read(calendarFocusedMonthProvider.notifier).nextMonth(),
                tooltip: context.l10n.month,
              ),
            ],
          ),
        ),
      ],
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
              padding: const EdgeInsets.only(bottom: CueSpacing.s12),
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
      padding: const EdgeInsets.fromLTRB(CueSpacing.s16, 0, CueSpacing.s8, 0),
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
            colorFilter: ColorFilter.mode(CueColors.accent, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              key: const Key('quick-add-field'),
              controller: controller,
              focusNode: focusNode,
              onSubmitted: (_) => onAdd(),
              style: TextStyle(
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

class MonthPickerPopover extends ConsumerStatefulWidget {
  const MonthPickerPopover({super.key});

  @override
  ConsumerState<MonthPickerPopover> createState() => _MonthPickerPopoverState();
}

class _MonthPickerPopoverState extends ConsumerState<MonthPickerPopover> {
  late int _displayedYear;

  @override
  void initState() {
    super.initState();
    final focused = ref.read(calendarFocusedMonthProvider);
    _displayedYear = focused.year;
  }

  @override
  Widget build(BuildContext context) {
    final focused = ref.watch(calendarFocusedMonthProvider);

    return Dialog(
      key: const Key('month-picker-popover'),
      backgroundColor: CueColors.popover,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: CueColors.border),
      ),
      insetPadding: CueInsets.dialog,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(CueSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  '$_displayedYear年',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: CueColors.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('month-picker-prev-year'),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: CueColors.secondary,
                  ),
                  onPressed: () => setState(() => _displayedYear--),
                  tooltip: '上一年',
                ),
                IconButton(
                  key: const Key('month-picker-today-year'),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.panorama_fish_eye_rounded,
                    color: CueColors.secondary,
                  ),
                  onPressed: () {
                    ref
                        .read(calendarFocusedMonthProvider.notifier)
                        .resetToToday();
                    Navigator.pop(context);
                  },
                  tooltip: '本月',
                ),
                IconButton(
                  key: const Key('month-picker-next-year'),
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: CueColors.secondary,
                  ),
                  onPressed: () => setState(() => _displayedYear++),
                  tooltip: '下一年',
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final month = index + 1;
                final isSelected =
                    focused.year == _displayedYear && focused.month == month;
                return Material(
                  color: isSelected ? CueColors.accent : Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: Key('month-picker-item-$month'),
                    onTap: () {
                      ref
                          .read(calendarFocusedMonthProvider.notifier)
                          .setMonth(DateTime(_displayedYear, month));
                      Navigator.pop(context);
                    },
                    child: Center(
                      child: Text(
                        '$month月',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? CueColors.onAccent
                              : CueColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog({
    required this.store,
    required this.onRunOperation,
    this.prefilledDate,
    this.prefilledGroup,
    this.prefilledPriority,
  });

  final TaskStore store;
  final Future<bool> Function(Future<void> Function()) onRunOperation;
  final DateTime? prefilledDate;
  final String? prefilledGroup;
  final int? prefilledPriority;

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late int _priority;
  late String _group;
  DateTime? _dueAt;
  String? _reminder;
  String? _recurrence;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _noteController = TextEditingController();
    _priority = widget.prefilledPriority ?? 2;
    _group = widget.prefilledGroup ?? TaskStore.defaultUngrouped;
    final today = widget.store.today;
    _dueAt = widget.prefilledDate == null
        ? DateTime(today.year, today.month, today.day, 18)
        : DateTime(
            widget.prefilledDate!.year,
            widget.prefilledDate!.month,
            widget.prefilledDate!.day,
            18,
          );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final result = await showCueDatePickerPopover(
      context: context,
      today: widget.store.today,
      initialDueAt: _dueAt,
      initialReminder: _reminder,
      initialRecurrence: _recurrence,
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.cleared) {
        _dueAt = null;
        _reminder = null;
        _recurrence = null;
      } else {
        _dueAt = result.dueAt;
        _reminder = result.reminder;
        _recurrence = result.recurrence;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        CueSpacing.s24,
        CueSpacing.s24,
        CueSpacing.s24,
        0,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        CueSpacing.s24,
        CueSpacing.s20,
        CueSpacing.s24,
        CueSpacing.s8,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        CueSpacing.s24,
        CueSpacing.s12,
        CueSpacing.s24,
        CueSpacing.s24,
      ),
      title: Text(
        context.l10n.newTask,
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
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.taskTitle,
                  hintText: context.l10n.taskTitleHint,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(labelText: context.l10n.note),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _priority,
                decoration: InputDecoration(labelText: context.l10n.priority),
                items: List.generate(
                  4,
                  (index) =>
                      DropdownMenuItem(value: index, child: Text('P$index')),
                ),
                onChanged: (value) => setState(() => _priority = value ?? 2),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: widget.store.groups.contains(_group)
                    ? _group
                    : TaskStore.defaultUngrouped,
                decoration: InputDecoration(labelText: context.l10n.group),
                items: widget.store.groups.map((g) {
                  return DropdownMenuItem<String>(value: g, child: Text(g));
                }).toList(),
                onChanged: (value) => setState(
                  () => _group = value ?? TaskStore.defaultUngrouped,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                key: const Key('desktop-new-task-duedate-picker'),
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.l10n.dueDate,
                    suffixIcon: const Icon(Icons.calendar_month_outlined),
                  ),
                  child: Text(
                    cueDueDateTimeLabel(
                      context,
                      _dueAt,
                      today: widget.store.today,
                    ),
                    style: TextStyle(
                      color: _dueAt == null
                          ? CueColors.secondary
                          : CueColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            if (_titleController.text.trim().isEmpty) return;
            final succeeded = await widget.onRunOperation(
              () => widget.store.addTask(
                title: _titleController.text,
                note: _noteController.text,
                priority: _priority,
                dueAt: _dueAt,
                reminder: _reminder,
                recurrence: _recurrence,
                group: _group == TaskStore.defaultUngrouped ? null : _group,
              ),
            );
            if (succeeded && context.mounted) {
              Navigator.pop(context);
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
  }
}
