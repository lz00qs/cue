import 'package:flutter/material.dart';

import 'cue_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin, this.initialError});

  final Future<void> Function(String email, String password) onLogin;
  final String? initialError;

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
              color: CueColors.canvas,
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
                  const Text(
                    'Move what’s next',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CueColors.tertiary, fontSize: 13),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    key: const Key('login-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      return text.contains('@') ? null : 'Enter a valid email';
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
                      labelText: 'Password',
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
                            ? 'Show password'
                            : 'Hide password',
                      ),
                    ),
                    validator: (value) => (value?.length ?? 0) >= 8
                        ? null
                        : 'Password must be at least 8 characters',
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
                          : const Text('Sign in'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This workspace has one administrator account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CueColors.tertiary, fontSize: 11),
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
