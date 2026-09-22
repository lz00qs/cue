import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/startup_view_store.dart';
import '../l10n/l10n.dart';
import '../state/app_state.dart';
import 'preference_picker.dart';

Future<void> showDefaultViewPicker(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final current = container.read(appControllerProvider).startupView;
  final l10n = context.l10n;
  final selected = await showCuePreferencePicker<StartupView>(
    context: context,
    title: l10n.defaultView,
    icon: Icons.home_outlined,
    selected: current,
    mobile: false,
    options: [
      CuePreferenceOption(
        value: StartupView.inbox,
        label: l10n.inbox,
        icon: Icons.inbox_outlined,
        key: const Key('default-view-option-inbox'),
      ),
      CuePreferenceOption(
        value: StartupView.today,
        label: l10n.today,
        icon: Icons.wb_sunny_outlined,
        key: const Key('default-view-option-today'),
      ),
      CuePreferenceOption(
        value: StartupView.upcoming,
        label: l10n.upcoming,
        icon: Icons.schedule_rounded,
        key: const Key('default-view-option-upcoming'),
      ),
      CuePreferenceOption(
        value: StartupView.list,
        label: l10n.list,
        icon: Icons.checklist_rounded,
        key: const Key('default-view-option-list'),
      ),
      CuePreferenceOption(
        value: StartupView.calendar,
        label: l10n.calendar,
        icon: Icons.calendar_month_outlined,
        key: const Key('default-view-option-calendar'),
      ),
      CuePreferenceOption(
        value: StartupView.quadrants,
        label: l10n.quadrants,
        icon: Icons.grid_view_rounded,
        key: const Key('default-view-option-quadrants'),
      ),
    ],
  );
  if (selected != null && context.mounted) {
    container.read(appControllerProvider.notifier).changeStartupView(selected);
  }
}
