import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

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
    final scope = CueLocaleScope.of(context);
    final l10n = context.l10n;
    final selected = scope.locale?.languageCode ?? 'system';
    return PopupMenuButton<String>(
      tooltip: l10n.language,
      initialValue: selected,
      onSelected: (value) {
        scope.onLocaleChanged(value == 'system' ? null : Locale(value));
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'system', child: Text(l10n.systemDefault)),
        PopupMenuItem(value: 'zh', child: Text(l10n.chinese)),
        PopupMenuItem(value: 'en', child: Text(l10n.english)),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 19),
            if (showLabel) ...[const SizedBox(width: 8), Text(l10n.language)],
          ],
        ),
      ),
    );
  }
}
