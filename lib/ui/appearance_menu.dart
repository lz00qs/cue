import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'preference_picker.dart';

class CueAppearanceScope extends InheritedWidget {
  const CueAppearanceScope({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required super.child,
  });

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onModeChanged;

  static CueAppearanceScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CueAppearanceScope>()!;

  @override
  bool updateShouldNotify(CueAppearanceScope oldWidget) =>
      mode != oldWidget.mode || onModeChanged != oldWidget.onModeChanged;
}

class AppearanceMenuButton extends StatelessWidget {
  const AppearanceMenuButton({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final scope = CueAppearanceScope.of(context);
    final l10n = context.l10n;
    return CuePreferenceButton(
      label: l10n.appearance,
      icon: scope.mode == ThemeMode.dark
          ? Icons.dark_mode_outlined
          : Icons.light_mode_outlined,
      showLabel: showLabel,
      onTap: () =>
          showAppearancePicker(context, mobile: showLabel ? false : null),
    );
  }
}

Future<void> showAppearancePicker(BuildContext context, {bool? mobile}) async {
  final scope = CueAppearanceScope.of(context);
  final l10n = context.l10n;
  final selected = await showCuePreferencePicker<ThemeMode>(
    context: context,
    title: l10n.appearance,
    icon: Icons.contrast_rounded,
    selected: scope.mode,
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
  if (selected != null && context.mounted) scope.onModeChanged(selected);
}
