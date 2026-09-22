import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/task_store.dart';
import '../l10n/l10n.dart';
import '../models/cue_task.dart';
import 'cue_theme.dart';

class CueActionButton extends StatelessWidget {
  const CueActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 36,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: primary ? CueColors.onAccent : CueColors.primary,
          backgroundColor: primary ? CueColors.accent : CueColors.subtle,
          side: primary ? BorderSide.none : BorderSide(color: CueColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(fontSize: 13, height: 18 / 13),
        ),
        child: Text(label),
      ),
    );
  }
}

class CueViewTab extends StatelessWidget {
  const CueViewTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.width = 88,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 36,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected ? CueColors.onAccent : CueColors.primary,
          backgroundColor: selected ? CueColors.accent : CueColors.subtle,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
          textStyle: const TextStyle(fontSize: 13, height: 18 / 13),
        ),
        child: Text(label),
      ),
    );
  }
}

class CuePriorityBadge extends StatelessWidget {
  const CuePriorityBadge({super.key, required this.priority});

  final int priority;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (priority) {
      0 => (CueColors.dangerBackground, CueColors.danger),
      1 => (CueColors.orangeBackground, CueColors.orange),
      2 => (CueColors.selected, CueColors.accent),
      _ => (CueColors.subtle, CueColors.secondary),
    };

    return Container(
      width: 40,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'P$priority',
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class CueTaskRow extends StatefulWidget {
  const CueTaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onOpen,
    this.metaOverride,
    this.referenceDate,
  });

  final CueTask task;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final String? metaOverride;
  final DateTime? referenceDate;

  @override
  State<CueTaskRow> createState() => _CueTaskRowState();
}

class _CueTaskRowState extends State<CueTaskRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: CueSpacing.s16),
          decoration: BoxDecoration(
            color: _hovered ? CueColors.hover : CueColors.card,
            border: Border.all(
              color: _hovered ? CueColors.strongBorder : CueColors.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(CueSpacing.s2),
                    child: SvgPicture.asset(
                      task.isCompleted
                          ? 'assets/figma/checkbox-completed.svg'
                          : 'assets/figma/checkbox.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? CueColors.secondary
                            : CueColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.metaOverride ??
                          cueTaskMeta(
                            context,
                            task,
                            today: widget.referenceDate,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CuePriorityBadge(priority: task.priority),
            ],
          ),
        ),
      ),
    );
  }
}

class CueTaskCard extends StatefulWidget {
  const CueTaskCard({
    super.key,
    required this.task,
    required this.onOpen,
    this.compact = false,
    this.referenceDate,
  });

  final CueTask task;
  final VoidCallback onOpen;
  final bool compact;
  final DateTime? referenceDate;

  @override
  State<CueTaskCard> createState() => _CueTaskCardState();
}

class _CueTaskCardState extends State<CueTaskCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: widget.compact ? 82 : 96,
          padding: CueInsets.card,
          decoration: BoxDecoration(
            color: CueColors.card,
            border: Border.all(
              color: _hovered ? CueColors.strongBorder : CueColors.border,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CueColors.shadow.withValues(alpha: 0.07),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: CueColors.shadow.withValues(alpha: 0.04),
                blurRadius: 18,
                spreadRadius: -6,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      cueCompactTaskMeta(
                        context,
                        widget.task,
                        today: widget.referenceDate,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CuePriorityBadge(priority: widget.task.priority),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String cueTaskMeta(BuildContext context, CueTask task, {DateTime? today}) {
  final l10n = context.l10n;
  if (task.isCompleted && task.completedAt != null) {
    return '${l10n.completedAt(_time(task.completedAt!))} · ${l10n.product}';
  }
  if (task.dueAt == null) return '${l10n.noDueDate} · ${l10n.personal}';
  final reference = TaskStore.dateOnly(today ?? DateTime.now());
  if (TaskStore.isSameDay(task.dueAt!, reference)) {
    return '${l10n.today}${_hasTime(task.dueAt!) ? ', ${_time(task.dueAt!)}' : ''} · ${cueTaskArea(context, task)}';
  }
  return '${formatShortMonthDay(context, task.dueAt!)} · ${cueTaskArea(context, task)}';
}

String cueCompactTaskMeta(
  BuildContext context,
  CueTask task, {
  DateTime? today,
}) {
  final l10n = context.l10n;
  if (task.isCompleted && task.completedAt != null) {
    return l10n.completedAt(_time(task.completedAt!));
  }
  if (task.dueAt == null) return l10n.noDueDate;
  final reference = TaskStore.dateOnly(today ?? DateTime.now());
  if (TaskStore.isSameDay(task.dueAt!, reference)) {
    return '${l10n.today}${_hasTime(task.dueAt!) ? ', ${_time(task.dueAt!)}' : ''}';
  }
  if (TaskStore.isSameDay(
    task.dueAt!,
    reference.add(const Duration(days: 1)),
  )) {
    return l10n.tomorrow;
  }
  return formatShortMonthDay(context, task.dueAt!);
}

String cueDueLabel(BuildContext context, CueTask task) {
  final l10n = context.l10n;
  if (task.dueAt == null) return l10n.noDueDate;
  final today = TaskStore.dateOnly(DateTime.now());
  if (TaskStore.isSameDay(task.dueAt!, today)) {
    return '${l10n.today}${_hasTime(task.dueAt!) ? ', ${_time(task.dueAt!)}' : ''}';
  }
  if (TaskStore.isSameDay(task.dueAt!, today.add(const Duration(days: 1)))) {
    return l10n.tomorrow;
  }
  return formatShortMonthDay(context, task.dueAt!);
}

String cueTaskArea(BuildContext context, CueTask task) {
  final l10n = context.l10n;
  if (task.title.contains('PCB')) return l10n.hardware;
  if (task.title.contains('thermal') || task.title.contains('signal')) {
    return l10n.simulation;
  }
  if (task.title.contains('report')) return l10n.writing;
  if (task.title.contains('lab')) return l10n.operations;
  return l10n.product;
}

bool _hasTime(DateTime date) => date.hour != 0 || date.minute != 0;

String _time(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
