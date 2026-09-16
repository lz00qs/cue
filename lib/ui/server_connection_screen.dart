import 'package:flutter/material.dart';

import '../data/api_client.dart';
import 'cue_theme.dart';

class ServerConnectionScreen extends StatefulWidget {
  const ServerConnectionScreen({
    super.key,
    required this.onConnect,
    this.initialUrl,
    this.onCancel,
  });

  final String? initialUrl;
  final Future<void> Function(String serverUrl) onConnect;
  final VoidCallback? onCancel;

  @override
  State<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends State<ServerConnectionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _serverUrl;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _serverUrl = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _serverUrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate() || _connecting) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await widget.onConnect(normalizeServerUrl(_serverUrl.text));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CueColors.subtle,
      appBar: widget.onCancel == null
          ? null
          : AppBar(
              backgroundColor: CueColors.subtle,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
            ),
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
                  Align(
                    child: Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: CueColors.selected,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.dns_outlined,
                        color: CueColors.accent,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Connect to Cue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CueColors.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the address of your Cue server',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CueColors.secondary, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    key: const Key('server-url-field'),
                    controller: _serverUrl,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                    enableSuggestions: false,
                    onFieldSubmitted: (_) => _connect(),
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'http://10.0.2.2:8080',
                      prefixIcon: Icon(Icons.language_rounded, size: 20),
                    ),
                    validator: (value) {
                      try {
                        normalizeServerUrl(value ?? '');
                        return null;
                      } on FormatException catch (error) {
                        return error.message.toString();
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Use the base address you open in a browser. “/api” is optional. Prefer HTTPS outside a trusted local network.',
                    style: TextStyle(color: CueColors.tertiary, fontSize: 11),
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
                    height: 48,
                    child: FilledButton(
                      key: const Key('server-connect-button'),
                      onPressed: _connecting ? null : _connect,
                      style: FilledButton.styleFrom(
                        backgroundColor: CueColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _connecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Connect'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'The server is verified before sign in. You can change it later in Settings.',
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
