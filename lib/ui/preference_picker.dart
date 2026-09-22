import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'cue_theme.dart';

class CuePreferenceOption<T> {
  const CuePreferenceOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.key,
  });

  final T value;
  final String label;
  final IconData icon;
  final Key key;
}

Future<T?> showCuePreferencePicker<T>({
  required BuildContext context,
  required String title,
  required IconData icon,
  required T selected,
  required List<CuePreferenceOption<T>> options,
  required bool mobile,
}) {
  final panel = _PreferencePanel<T>(
    title: title,
    icon: icon,
    selected: selected,
    options: options,
    mobile: mobile,
  );

  if (mobile) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: CueColors.modalBarrier,
      builder: (context) => panel,
    );
  }
  return showDialog<T>(
    context: context,
    barrierColor: CueColors.modalBarrier,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: CueInsets.dialog,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: panel,
      ),
    ),
  );
}

class CuePreferenceButton extends StatelessWidget {
  const CuePreferenceButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.showLabel = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: CueColors.sidebarHover,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: showLabel ? CueSpacing.s12 : CueSpacing.s8,
              vertical: CueSpacing.s8,
            ),
            child: Row(
              mainAxisSize: showLabel ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: CueColors.secondary),
                if (showLabel) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: CueColors.primary, fontSize: 13),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: CueColors.secondary,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferencePanel<T> extends StatelessWidget {
  const _PreferencePanel({
    required this.title,
    required this.icon,
    required this.selected,
    required this.options,
    required this.mobile,
  });

  final String title;
  final IconData icon;
  final T selected;
  final List<CuePreferenceOption<T>> options;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final radius = mobile
        ? const BorderRadius.vertical(top: Radius.circular(24))
        : BorderRadius.circular(20);
    return Material(
      color: CueColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: CueColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            CueSpacing.s20,
            mobile ? CueSpacing.s12 : CueSpacing.s20,
            CueSpacing.s20,
            CueSpacing.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mobile) ...[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CueColors.strongBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: CueColors.selected,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: CueColors.accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: CueColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: context.l10n.close,
                    icon: Icon(
                      Icons.close_rounded,
                      color: CueColors.secondary,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (var index = 0; index < options.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                _PreferenceOptionRow<T>(
                  option: options[index],
                  selected: selected == options[index].value,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceOptionRow<T> extends StatelessWidget {
  const _PreferenceOptionRow({required this.option, required this.selected});

  final CuePreferenceOption<T> option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? CueColors.selected : CueColors.subtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? CueColors.accent : CueColors.border,
            width: selected ? 1.2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: option.key,
          onTap: () => Navigator.pop(context, option.value),
          child: SizedBox(
            height: 54,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  option.icon,
                  size: 20,
                  color: selected ? CueColors.accent : CueColors.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      color: CueColors.primary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, color: CueColors.accent, size: 20),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
