import 'package:flutter/material.dart';

import 'data/api_client.dart';
import 'data/task_store.dart';
import 'data/token_store.dart';
import 'ui/cue_home.dart';
import 'ui/cue_theme.dart';
import 'ui/login_screen.dart';

void main() {
  runApp(const CueApp());
}

class CueApp extends StatefulWidget {
  const CueApp({super.key}) : demoMode = false;
  const CueApp.demo({super.key}) : demoMode = true;

  final bool demoMode;

  @override
  State<CueApp> createState() => _CueAppState();
}

class _CueAppState extends State<CueApp> {
  late final TokenStore? _tokens;
  late final ApiClient? _api;
  TaskStore? _store;
  String? _email;
  String? _initialError;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      _tokens = null;
      _api = null;
      _store = TaskStore.demo();
      _email = 'demo@cue.local';
      _booting = false;
    } else {
      _tokens = TokenStore();
      _api = ApiClient(_tokens!);
      _restore();
    }
  }

  Future<void> _restore() async {
    try {
      final email = await _api!.restoreSession();
      await _openWorkspace(email);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _booting = false;
        if (error is ApiException && error.statusCode != 401) {
          _initialError = error.message;
        }
      });
    }
  }

  Future<void> _login(String email, String password) async {
    final normalizedEmail = await _api!.login(email, password);
    try {
      await _openWorkspace(normalizedEmail);
    } catch (error) {
      await _api.logout();
      rethrow;
    }
  }

  Future<void> _openWorkspace(String email) async {
    final store = TaskStore.remote(_api!);
    try {
      await store.load();
    } catch (_) {
      store.dispose();
      rethrow;
    }
    if (!mounted) {
      store.dispose();
      return;
    }
    setState(() {
      _store?.dispose();
      _store = store;
      _email = email;
      _initialError = null;
      _booting = false;
    });
  }

  Future<void> _logout() async {
    await _api?.logout();
    if (!mounted) return;
    setState(() {
      _store?.dispose();
      _store = null;
      _email = null;
      _initialError = null;
    });
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cue — Move what’s next',
      debugShowCheckedModeBanner: false,
      theme: CueTheme.light,
      home: _booting
          ? const _BootScreen()
          : _store == null
          ? LoginScreen(onLogin: _login, initialError: _initialError)
          : CueHome(
              store: _store!,
              userEmail: _email,
              onLogout: widget.demoMode ? null : _logout,
            ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: CueColors.subtle,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cue',
              style: TextStyle(
                color: CueColors.primary,
                fontSize: 32,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
