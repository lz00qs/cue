import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'cue_theme.dart';
import 'language_menu.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLogin,
    this.initialError,
    this.serverUrl,
    this.onChangeServer,
  });

  final Future<void> Function(String email, String password) onLogin;
  final String? initialError;
  final String? serverUrl;
  final VoidCallback? onChangeServer;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'admin@cue.local');
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onLogin(_email.text, _password.text);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CueColors.subtle,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: CueColors.card,
              border: Border.all(color: CueColors.border),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x101A1C26),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: LanguageMenuButton(),
                  ),
                  const Text(
                    'Cue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CueColors.primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CueColors.tertiary,
                      fontSize: 13,
                    ),
                  ),
                  if (widget.serverUrl != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      decoration: BoxDecoration(
                        color: CueColors.subtle,
                        border: Border.all(color: CueColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.dns_outlined,
                            size: 18,
                            color: CueColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.serverUrl!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: CueColors.secondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('change-server-button'),
                            onPressed: widget.onChangeServer,
                            child: Text(context.l10n.change),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('login-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(labelText: context.l10n.email),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      return text.contains('@')
                          ? null
                          : context.l10n.enterValidEmail;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('login-password'),
                    controller: _password,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: context.l10n.password,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
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
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CueColors.dangerBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: CueColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 46,
                    child: FilledButton(
                      key: const Key('login-submit'),
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: CueColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(context.l10n.signIn),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.singleAdministrator,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CueColors.tertiary,
                      fontSize: 11,
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
