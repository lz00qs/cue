import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/l10n.dart';
import 'cue_theme.dart';

const cueAuthor = 'lz00qs';
const cueAuthorEmail = 'lz00qs@gmail.com';

class CueAppInfo {
  const CueAppInfo({required this.version, required this.buildNumber});

  const CueAppInfo.fallback() : version = '1.0.0', buildNumber = '1';

  final String version;
  final String buildNumber;

  String get versionLabel =>
      buildNumber.isEmpty ? version : '$version ($buildNumber)';
}

Future<CueAppInfo> loadCueAppInfo() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    return CueAppInfo(
      version: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
    );
  } catch (_) {
    // Widget tests and unsupported embedders do not always expose package info.
    return const CueAppInfo.fallback();
  }
}

Future<void> showCueAbout(BuildContext context, {required bool mobile}) {
  if (mobile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CueColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: CueInsets.mobileSheet,
          child: _CueAboutContent(mobile: true),
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: CueColors.modalBarrier,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: CueInsets.dialog,
          child: const _CueAboutContent(mobile: false),
        ),
      ),
    ),
  );
}

class _CueAboutContent extends StatefulWidget {
  const _CueAboutContent({required this.mobile});

  final bool mobile;

  @override
  State<_CueAboutContent> createState() => _CueAboutContentState();
}

class _CueAboutContentState extends State<_CueAboutContent> {
  late final Future<CueAppInfo> _appInfo = loadCueAppInfo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.mobile) ...[
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
          const SizedBox(height: CueSpacing.s20),
        ],
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: CueColors.selected,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: CueColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: CueSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.aboutCue,
                    style: TextStyle(
                      color: CueColors.primary,
                      fontSize: widget.mobile ? 20 : 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.aboutCueDescription,
                    style: TextStyle(color: CueColors.secondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (!widget.mobile)
              IconButton(
                key: const Key('about-close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: context.l10n.close,
              ),
          ],
        ),
        const SizedBox(height: CueSpacing.s24),
        FutureBuilder<CueAppInfo>(
          future: _appInfo,
          initialData: const CueAppInfo.fallback(),
          builder: (context, snapshot) {
            final appInfo = snapshot.data ?? const CueAppInfo.fallback();
            return _AboutInfoRow(
              key: const Key('about-version'),
              icon: Icons.info_outline_rounded,
              label: context.l10n.version,
              value: appInfo.versionLabel,
            );
          },
        ),
        const SizedBox(height: CueSpacing.s10),
        _AboutInfoRow(
          key: const Key('about-author'),
          icon: Icons.person_outline_rounded,
          label: context.l10n.author,
          value: cueAuthor,
        ),
        const SizedBox(height: CueSpacing.s10),
        _AboutInfoRow(
          key: const Key('about-author-email'),
          icon: Icons.mail_outline_rounded,
          label: context.l10n.email,
          value: cueAuthorEmail,
          selectable: true,
        ),
        if (widget.mobile) const SizedBox(height: CueSpacing.s8),
      ],
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final valueStyle = TextStyle(
      color: CueColors.primary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CueSpacing.s14,
        vertical: CueSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: CueColors.subtle,
        border: Border.all(color: CueColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: CueColors.secondary),
          const SizedBox(width: CueSpacing.s12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: CueColors.secondary, fontSize: 13),
            ),
          ),
          const SizedBox(width: CueSpacing.s12),
          if (selectable)
            Flexible(child: SelectableText(value, style: valueStyle))
          else
            Flexible(
              child: Text(value, textAlign: TextAlign.end, style: valueStyle),
            ),
        ],
      ),
    );
  }
}
