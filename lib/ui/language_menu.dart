import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'preference_picker.dart';

class CueLocaleScope extends InheritedWidget {
  const CueLocaleScope({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    required super.child,
  });

  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;

  static CueLocaleScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CueLocaleScope>()!;
  }

  @override
  bool updateShouldNotify(CueLocaleScope oldWidget) =>
      locale != oldWidget.locale ||
      onLocaleChanged != oldWidget.onLocaleChanged;
}

class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key, this.showLabel = false});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CuePreferenceButton(
      label: l10n.language,
      icon: Icons.language_rounded,
      showLabel: showLabel,
      onTap: () =>
          showLanguagePicker(context, mobile: showLabel ? false : null),
    );
  }
}

Future<void> showLanguagePicker(BuildContext context, {bool? mobile}) async {
  final scope = CueLocaleScope.of(context);
  final l10n = context.l10n;
  final selected = await showCuePreferencePicker<String>(
    context: context,
    title: l10n.language,
    icon: Icons.language_rounded,
    selected: scope.locale?.languageCode ?? 'system',
    mobile: mobile ?? MediaQuery.sizeOf(context).width < 840,
    options: [
      CuePreferenceOption(
        value: 'system',
        label: l10n.systemDefault,
        icon: Icons.devices_rounded,
        key: const Key('language-option-system'),
      ),
      CuePreferenceOption(
        value: 'zh',
        label: l10n.chinese,
        icon: Icons.translate_rounded,
        key: const Key('language-option-zh'),
      ),
      CuePreferenceOption(
        value: 'en',
        label: l10n.english,
        icon: Icons.abc_rounded,
        key: const Key('language-option-en'),
      ),
    ],
  );
  if (selected != null && context.mounted) {
    scope.onLocaleChanged(selected == 'system' ? null : Locale(selected));
  }
}
