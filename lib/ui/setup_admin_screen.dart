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
    this.initialError,
    this.serverUrl,
    this.onChangeServer,
  });

  final Future<void> Function(String email, String password) onSetup;
  final String? initialError;
  final String? serverUrl;
  final VoidCallback? onChangeServer;

  @override
  ConsumerState<SetupAdminScreen> createState() => _SetupAdminScreenState();
}

class _SetupAdminScreenState extends ConsumerState<SetupAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'admin@cue.local');
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
      backgroundColor: CueColors.canvas,
      body: Center(
        child: SingleChildScrollView(
          padding: CueInsets.screen,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(CueSpacing.s36),
            decoration: BoxDecoration(
              color: CueColors.card,
              border: Border.all(color: CueColors.border),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: CueColors.shadow.withValues(
                    alpha: CueColors.isDark ? 0.35 : 0.06,
                  ),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CueSpacing.s10,
                          vertical: CueSpacing.s4,
                        ),
                        decoration: BoxDecoration(
                          color: CueColors.selected,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          context.l10n.initialSetup,
                          style: TextStyle(
                            color: CueColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const LanguageMenuButton(),
                    ],
                  ),
                  const SizedBox(height: CueSpacing.s20),
                  Text(
                    'Cue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CueColors.primary,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: CueSpacing.s8),
                  Text(
                    context.l10n.setupAdminTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CueColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: CueSpacing.s4),
                  Text(
                    context.l10n.setupAdminSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CueColors.secondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (widget.serverUrl != null) ...[
                    const SizedBox(height: CueSpacing.s20),
                    Container(
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
                          Icon(
                            Icons.dns_outlined,
                            size: 18,
                            color: CueColors.secondary,
                          ),
                          const SizedBox(width: CueSpacing.s8),
                          Expanded(
                            child: Text(
                              widget.serverUrl!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: CueColors.secondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (widget.onChangeServer != null)
                            TextButton(
                              key: const Key('change-server-button'),
                              onPressed: widget.onChangeServer,
                              child: Text(context.l10n.change),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: CueSpacing.s24),
                  TextFormField(
                    key: const Key('setup-email'),
                    controller: _email,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username,
                    ],
                    style: TextStyle(color: CueColors.primary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: context.l10n.email,
                      prefixIcon: Icon(
                        Icons.mail_outline_rounded,
                        size: 18,
                        color: CueColors.secondary,
                      ),
                    ),
                    validator: (value) =>
                        isValidEmail(value) ? null : context.l10n.enterValidEmail,
                  ),
                  const SizedBox(height: CueSpacing.s16),
                  TextFormField(
                    key: const Key('setup-password'),
                    controller: _password,
                    obscureText: _obscurePassword,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    autofillHints: const [AutofillHints.newPassword],
                    style: TextStyle(color: CueColors.primary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: context.l10n.password,
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: CueColors.secondary,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => ref
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
                  const SizedBox(height: CueSpacing.s16),
                  TextFormField(
                    key: const Key('setup-confirm-password'),
                    controller: _confirmPassword,
                    obscureText: _obscureConfirmPassword,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    style: TextStyle(color: CueColors.primary, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: context.l10n.confirmPassword,
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: CueColors.secondary,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => ref
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
                    const SizedBox(height: CueSpacing.s16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CueSpacing.s12,
                        vertical: CueSpacing.s10,
                      ),
                      decoration: BoxDecoration(
                        color: CueColors.dangerBackground,
                        border: Border.all(
                          color: CueColors.danger.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: CueColors.danger,
                            size: 16,
                          ),
                          const SizedBox(width: CueSpacing.s8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: CueColors.danger,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: CueSpacing.s24),
                  SizedBox(
                    height: 46,
                    child: FilledButton(
                      key: const Key('setup-submit'),
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: CueColors.accent,
                        foregroundColor: CueColors.onAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
                          : Text(context.l10n.createAndSignIn),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
