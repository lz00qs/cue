import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../l10n/l10n.dart';
import 'cue_theme.dart';

typedef AccountUpdater = Future<void> Function({
  required String currentPassword,
  String? email,
  String? newPassword,
});

Future<void> showAccountSettings(
  BuildContext context, {
  required String email,
  required AccountUpdater onSave,
  required bool mobile,
}) {
  if (mobile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CueColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: CueInsets.mobileSheet,
            child: _AccountSettingsForm(
              email: email,
              onSave: onSave,
              mobile: true,
            ),
          ),
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: CueColors.modalBarrier,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: SingleChildScrollView(
          padding: CueInsets.dialog,
          child: _AccountSettingsForm(
            email: email,
            onSave: onSave,
            mobile: false,
          ),
        ),
      ),
    ),
  );
}

class _AccountSettingsForm extends StatefulWidget {
  const _AccountSettingsForm({
    required this.email,
    required this.onSave,
    required this.mobile,
  });

  final String email;
  final AccountUpdater onSave;
  final bool mobile;

  @override
  State<_AccountSettingsForm> createState() => _AccountSettingsFormState();
}

class _AccountSettingsFormState extends State<_AccountSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _submitting = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _email.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _emailChanged =>
      _email.text.trim().toLowerCase() != widget.email.trim().toLowerCase();

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final passwordChanged = _newPassword.text.isNotEmpty;
    if (!_emailChanged && !passwordChanged) {
      setState(() => _error = context.l10n.noAccountChanges);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSave(
        currentPassword: _currentPassword.text,
        email: _emailChanged ? _email.text.trim() : null,
        newPassword: passwordChanged ? _newPassword.text : null,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.accountUpdated),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
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
                Expanded(
                  child: Text(
                    context.l10n.accountSettings,
                    style: TextStyle(
                      color: CueColors.primary,
                      fontSize: widget.mobile ? 20 : 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!widget.mobile)
                  IconButton(
                    key: const Key('account-close'),
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.l10n.close,
                  ),
              ],
            ),
            const SizedBox(height: CueSpacing.s6),
            Text(
              context.l10n.accountSettingsDescription,
              style: TextStyle(
                color: CueColors.secondary,
                fontSize: 13,
                height: 18 / 13,
              ),
            ),
            const SizedBox(height: CueSpacing.s24),
            TextFormField(
              key: const Key('account-email'),
              controller: _email,
              enabled: !_submitting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: (_) => _clearError(),
              decoration: InputDecoration(
                labelText: context.l10n.loginEmail,
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
            _PasswordField(
              key: const Key('account-current-password'),
              controller: _currentPassword,
              label: context.l10n.currentPassword,
              enabled: !_submitting,
              obscureText: _obscureCurrentPassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.next,
              onChanged: (_) => _clearError(),
              onToggleVisibility: () => setState(
                () => _obscureCurrentPassword = !_obscureCurrentPassword,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.l10n.currentPasswordRequired;
                }
                return value.length >= 8
                    ? null
                    : context.l10n.passwordMinLength;
              },
            ),
            const SizedBox(height: CueSpacing.s20),
            Text(
              context.l10n.changePassword,
              style: TextStyle(
                color: CueColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: CueSpacing.s4),
            Text(
              context.l10n.newPasswordOptional,
              style: TextStyle(color: CueColors.tertiary, fontSize: 12),
            ),
            const SizedBox(height: CueSpacing.s12),
            _PasswordField(
              key: const Key('account-new-password'),
              controller: _newPassword,
              label: context.l10n.newPassword,
              enabled: !_submitting,
              obscureText: _obscureNewPassword,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                _clearError();
                if (_confirmPassword.text.isNotEmpty) {
                  _formKey.currentState?.validate();
                }
              },
              onToggleVisibility: () =>
                  setState(() => _obscureNewPassword = !_obscureNewPassword),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                return value.length >= 8
                    ? null
                    : context.l10n.passwordMinLength;
              },
            ),
            const SizedBox(height: CueSpacing.s14),
            _PasswordField(
              key: const Key('account-confirm-password'),
              controller: _confirmPassword,
              label: context.l10n.confirmNewPassword,
              enabled: !_submitting,
              obscureText: _obscureConfirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onChanged: (_) => _clearError(),
              onFieldSubmitted: (_) => _submit(),
              onToggleVisibility: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              validator: (value) {
                if (_newPassword.text.isEmpty && (value?.isEmpty ?? true)) {
                  return null;
                }
                if (value != _newPassword.text) {
                  return context.l10n.passwordsDoNotMatch;
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: CueSpacing.s14),
              Container(
                key: const Key('account-error'),
                padding: const EdgeInsets.all(CueSpacing.s12),
                decoration: BoxDecoration(
                  color: CueColors.dangerBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: CueColors.danger, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: CueSpacing.s24),
            SizedBox(
              height: 48,
              child: FilledButton(
                key: const Key('account-save'),
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: CueColors.accent,
                  foregroundColor: CueColors.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                    : Text(context.l10n.saveChanges),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.enabled,
    required this.obscureText,
    required this.autofillHints,
    required this.textInputAction,
    required this.onChanged,
    required this.onToggleVisibility,
    required this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool obscureText;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleVisibility;
  final FormFieldValidator<String> validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          size: 19,
          color: CueColors.secondary,
        ),
        suffixIcon: IconButton(
          onPressed: enabled ? onToggleVisibility : null,
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: CueColors.secondary,
          ),
          tooltip: obscureText
              ? context.l10n.showPassword
              : context.l10n.hidePassword,
        ),
      ),
    );
  }
}
