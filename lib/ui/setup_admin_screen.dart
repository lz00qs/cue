import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../l10n/l10n.dart';
import '../state/page_state.dart';
import 'cue_theme.dart';
import 'language_menu.dart';

class SetupAdminScreen extends ConsumerStatefulWidget {
  const SetupAdminScreen({
    super.key,
    required this.onSetup,
    this.setupAvailable = true,
    this.initialError,
    this.serverUrl,
    this.onChangeServer,
  });

  final Future<void> Function(String email, String password) onSetup;
  final bool setupAvailable;
  final String? initialError;
  final String? serverUrl;
  final VoidCallback? onChangeServer;

  @override
  ConsumerState<SetupAdminScreen> createState() => _SetupAdminScreenState();
}

class _SetupAdminScreenState extends ConsumerState<SetupAdminScreen> {
  static const _wideBreakpoint = 1040.0;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool get _submitting => ref.read(setupAdminUiProvider).submitting;
  bool get _obscurePassword => ref.read(setupAdminUiProvider).obscurePassword;
  bool get _obscureConfirmPassword =>
      ref.read(setupAdminUiProvider).obscureConfirmPassword;

  String? get _error {
    final ui = ref.read(setupAdminUiProvider);
    return ui.interacted ? ui.error : widget.initialError;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) {
      ref.read(setupAdminUiProvider.notifier).setError(null);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    ref.read(setupAdminUiProvider.notifier).setSubmitting(true);
    try {
      await widget.onSetup(_email.text.trim(), _password.text);
    } catch (error) {
      if (!mounted) return;
      ref.read(setupAdminUiProvider.notifier).setError(error.toString());
    } finally {
      if (mounted) {
        ref.read(setupAdminUiProvider.notifier).setSubmitting(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(setupAdminUiProvider);
    return Scaffold(
      backgroundColor: CueColors.subtle,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideBreakpoint;
          final pagePadding = wide ? CueSpacing.s32 : CueSpacing.s20;
          return Stack(
            children: [
              const Positioned.fill(child: _SetupBackdrop()),
              SingleChildScrollView(
                padding: EdgeInsets.all(pagePadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - pagePadding * 2,
                  ),
                  child: Center(
                    child: Container(
                      key: const Key('setup-card'),
                      width: wide ? 920 : 480,
                      decoration: BoxDecoration(
                        color: CueColors.card,
                        border: Border.all(color: CueColors.border),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: CueColors.shadow.withValues(
                              alpha: CueColors.isDark ? 0.42 : 0.09,
                            ),
                            blurRadius: 48,
                            spreadRadius: -8,
                            offset: const Offset(0, 24),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: wide
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(
                                    width: 348,
                                    child: _SetupBrandPanel(),
                                  ),
                                  Expanded(
                                    child: widget.setupAvailable
                                        ? _buildForm(compact: false)
                                        : _buildUnavailable(compact: false),
                                  ),
                                ],
                              ),
                            )
                          : widget.setupAvailable
                          ? _buildForm(compact: true)
                          : _buildUnavailable(compact: true),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnavailable({required bool compact}) {
    final horizontalPadding = compact ? CueSpacing.s24 : CueSpacing.s40;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? CueSpacing.s24 : CueSpacing.s32,
        horizontalPadding,
        compact ? CueSpacing.s28 : CueSpacing.s36,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const _CompactBrand(), const LanguageMenuButton()],
            ),
            const SizedBox(height: CueSpacing.s24),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: const LanguageMenuButton(),
            ),
          Text(
            context.l10n.setupUnavailableTitle,
            style: TextStyle(
              color: CueColors.primary,
              fontSize: compact ? 25 : 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: CueSpacing.s12),
          Text(
            context.l10n.setupUnavailableDescription,
            style: TextStyle(
              color: CueColors.secondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm({required bool compact}) {
    final horizontalPadding = compact ? CueSpacing.s24 : CueSpacing.s40;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        compact ? CueSpacing.s24 : CueSpacing.s32,
        horizontalPadding,
        compact ? CueSpacing.s28 : CueSpacing.s36,
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const _CompactBrand(), const LanguageMenuButton()],
                ),
                const SizedBox(height: CueSpacing.s24),
                Text(
                  context.l10n.setupAdminTitle,
                  style: TextStyle(
                    color: CueColors.primary,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.setupAdminTitle,
                        style: TextStyle(
                          color: CueColors.primary,
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: CueSpacing.s16),
                    const LanguageMenuButton(),
                  ],
                ),
              const SizedBox(height: CueSpacing.s8),
              Text(
                context.l10n.setupAdminSubtitle,
                style: TextStyle(
                  color: CueColors.secondary,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              if (widget.serverUrl != null) ...[
                const SizedBox(height: CueSpacing.s20),
                _ServerAddress(
                  serverUrl: widget.serverUrl!,
                  onChangeServer: widget.onChangeServer,
                ),
              ],
              const SizedBox(height: CueSpacing.s24),
              TextFormField(
                key: const Key('setup-email'),
                controller: _email,
                enabled: !_submitting,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.email,
                  AutofillHints.username,
                ],
                onChanged: (_) => _clearError(),
                style: TextStyle(color: CueColors.primary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: context.l10n.email,
                  prefixIcon: Icon(
                    Icons.mail_outline_rounded,
                    size: 19,
                    color: CueColors.secondary,
                  ),
                ),
                validator: (value) =>
                    isValidEmail(value) ? null : context.l10n.enterValidEmail,
              ),
              const SizedBox(height: CueSpacing.s14),
              TextFormField(
                key: const Key('setup-password'),
                controller: _password,
                enabled: !_submitting,
                obscureText: _obscurePassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearError(),
                style: TextStyle(color: CueColors.primary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: context.l10n.password,
                  prefixIcon: Icon(
                    Icons.lock_outline_rounded,
                    size: 19,
                    color: CueColors.secondary,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _submitting
                        ? null
                        : () => ref
                              .read(setupAdminUiProvider.notifier)
                              .togglePasswordVisibility(),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: CueColors.secondary,
                    ),
                    tooltip: _obscurePassword
                        ? context.l10n.showPassword
                        : context.l10n.hidePassword,
                  ),
                ),
                validator: (value) => (value?.length ?? 0) >= 8
                    ? null
                    : context.l10n.passwordMinLength,
              ),
              const SizedBox(height: CueSpacing.s14),
              TextFormField(
                key: const Key('setup-confirm-password'),
                controller: _confirmPassword,
                enabled: !_submitting,
                obscureText: _obscureConfirmPassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onChanged: (_) => _clearError(),
                onFieldSubmitted: (_) => _submit(),
                style: TextStyle(color: CueColors.primary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: context.l10n.confirmPassword,
                  prefixIcon: Icon(
                    Icons.verified_user_outlined,
                    size: 19,
                    color: CueColors.secondary,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _submitting
                        ? null
                        : () => ref
                              .read(setupAdminUiProvider.notifier)
                              .toggleConfirmPasswordVisibility(),
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: CueColors.secondary,
                    ),
                    tooltip: _obscureConfirmPassword
                        ? context.l10n.showPassword
                        : context.l10n.hidePassword,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.l10n.confirmPasswordRequired;
                  }
                  if (value != _password.text) {
                    return context.l10n.passwordsDoNotMatch;
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: CueSpacing.s14),
                _ErrorMessage(message: _error!),
              ],
              const SizedBox(height: CueSpacing.s20),
              _SecurityNote(message: context.l10n.credentialsSecurityNote),
              const SizedBox(height: CueSpacing.s20),
              SizedBox(
                height: 50,
                child: FilledButton(
                  key: const Key('setup-submit'),
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: CueColors.accent,
                    foregroundColor: CueColors.onAccent,
                    disabledBackgroundColor: CueColors.accent.withValues(
                      alpha: 0.55,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CueColors.onAccent,
                          ),
                        )
                      : compact
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(context.l10n.createAndSignIn),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(context.l10n.createAndSignIn),
                            const SizedBox(width: CueSpacing.s8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
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

class _SetupBackdrop extends StatelessWidget {
  const _SetupBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -170,
            right: -110,
            child: _GlowOrb(
              size: 380,
              color: CueColors.accent.withValues(
                alpha: CueColors.isDark ? 0.10 : 0.08,
              ),
            ),
          ),
          Positioned(
            bottom: -210,
            left: -160,
            child: _GlowOrb(
              size: 440,
              color: CueColors.accent.withValues(
                alpha: CueColors.isDark ? 0.07 : 0.045,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SetupBrandPanel extends StatelessWidget {
  const _SetupBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('setup-brand-panel'),
      padding: const EdgeInsets.all(CueSpacing.s40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A63F3), Color(0xFF2344BF)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -96,
            right: -96,
            child: _PanelOrb(size: 230, opacity: 0.09),
          ),
          const Positioned(
            bottom: -74,
            left: -92,
            child: _PanelOrb(size: 210, opacity: 0.07),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandMark(onColor: true),
              const SizedBox(height: CueSpacing.s40),
              Text(
                context.l10n.tagline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: CueSpacing.s12),
              Text(
                context.l10n.planWhatComesNext,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              const _WorkspacePreview(),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelOrb extends StatelessWidget {
  const _PanelOrb({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _WorkspacePreview extends StatelessWidget {
  const _WorkspacePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CueSpacing.s16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_sunny_outlined,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: CueSpacing.s8),
              Text(
                context.l10n.focusForToday,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: CueSpacing.s16),
          const _PreviewTask(widthFactor: 0.86),
          const SizedBox(height: CueSpacing.s10),
          const _PreviewTask(widthFactor: 0.64),
          const SizedBox(height: CueSpacing.s10),
          const _PreviewTask(widthFactor: 0.74, completed: true),
        ],
      ),
    );
  }
}

class _PreviewTask extends StatelessWidget {
  const _PreviewTask({required this.widthFactor, this.completed = false});

  final double widthFactor;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: completed ? Colors.white : Colors.transparent,
            border: Border.all(
              color: Colors.white.withValues(alpha: completed ? 0.9 : 0.6),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(5),
          ),
          child: completed
              ? const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF3158DD),
                  size: 12,
                )
              : null,
        ),
        const SizedBox(width: CueSpacing.s10),
        Expanded(
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            alignment: Alignment.centerLeft,
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: completed ? 0.28 : 0.58),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: _BrandMark(onColor: false),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.onColor});

  final bool onColor;

  @override
  Widget build(BuildContext context) {
    final foreground = onColor ? Colors.white : CueColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          key: const Key('setup-app-icon'),
          borderRadius: BorderRadius.circular(11),
          child: Image.asset(
            'web/icons/Icon-192.png',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(width: CueSpacing.s12),
        Text(
          'Cue',
          style: TextStyle(
            color: foreground,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _ServerAddress extends StatelessWidget {
  const _ServerAddress({required this.serverUrl, required this.onChangeServer});

  final String serverUrl;
  final VoidCallback? onChangeServer;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.only(
        left: CueSpacing.s12,
        right: CueSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: CueColors.subtle,
        border: Border.all(color: CueColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.dns_outlined, size: 18, color: CueColors.secondary),
          const SizedBox(width: CueSpacing.s8),
          Expanded(
            child: Text(
              serverUrl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: CueColors.secondary, fontSize: 12),
            ),
          ),
          if (onChangeServer != null)
            TextButton(
              key: const Key('change-server-button'),
              onPressed: onChangeServer,
              child: Text(context.l10n.change),
            ),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CueSpacing.s12,
        vertical: CueSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: CueColors.greenBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.shield_outlined,
              color: CueColors.green,
              size: 17,
            ),
          ),
          const SizedBox(width: CueSpacing.s8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: CueColors.isDark
                    ? const Color(0xFF8FD8B2)
                    : const Color(0xFF287D52),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CueSpacing.s12,
        vertical: CueSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: CueColors.dangerBackground,
        border: Border.all(color: CueColors.danger.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              color: CueColors.danger,
              size: 16,
            ),
          ),
          const SizedBox(width: CueSpacing.s8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: CueColors.danger,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
