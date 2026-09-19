import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/app_state.dart';
import 'preference_picker.dart';

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
  final container = ProviderScope.containerOf(context, listen: false);
  final locale = container.read(appControllerProvider).locale;
  final l10n = context.l10n;
  final selected = await showCuePreferencePicker<String>(
    context: context,
    title: l10n.language,
    icon: Icons.language_rounded,
    selected: locale?.languageCode ?? 'system',
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
        icon: Icons.text_format_rounded,
        key: const Key('language-option-en'),
      ),
    ],
  );
  if (selected != null && context.mounted) {
    container
        .read(appControllerProvider.notifier)
        .changeLocale(selected == 'system' ? null : Locale(selected));
  }
}
