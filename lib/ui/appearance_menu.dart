import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/app_state.dart';
import 'preference_picker.dart';

class AppearanceMenuButton extends ConsumerWidget {
  const AppearanceMenuButton({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      appControllerProvider.select((app) => app.themeMode),
    );
    final l10n = context.l10n;
    return CuePreferenceButton(
      label: l10n.appearance,
      icon: mode == ThemeMode.dark
          ? Icons.dark_mode_outlined
          : Icons.light_mode_outlined,
      showLabel: showLabel,
      onTap: () =>
          showAppearancePicker(context, mobile: showLabel ? false : null),
    );
  }
}

Future<void> showAppearancePicker(BuildContext context, {bool? mobile}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final mode = container.read(appControllerProvider).themeMode;
  final l10n = context.l10n;
  final selected = await showCuePreferencePicker<ThemeMode>(
    context: context,
    title: l10n.appearance,
    icon: Icons.contrast_rounded,
    selected: mode,
    mobile: mobile ?? MediaQuery.sizeOf(context).width < 840,
    options: [
      CuePreferenceOption(
        value: ThemeMode.light,
        label: l10n.light,
        icon: Icons.light_mode_outlined,
        key: const Key('appearance-option-light'),
      ),
      CuePreferenceOption(
        value: ThemeMode.dark,
        label: l10n.dark,
        icon: Icons.dark_mode_outlined,
        key: const Key('appearance-option-dark'),
      ),
    ],
  );
  if (selected != null && context.mounted) {
    container.read(appControllerProvider.notifier).changeTheme(selected);
  }
}
