import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/api_client.dart';
import 'data/locale_store.dart';
import 'data/server_config_store.dart';
import 'data/task_store.dart';
import 'data/token_store.dart';
import 'l10n/l10n.dart';
import 'ui/cue_home.dart';
import 'ui/cue_theme.dart';
import 'ui/language_menu.dart';
import 'ui/login_screen.dart';
import 'ui/server_connection_screen.dart';

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
  late final LocaleStore? _localeStore;
  ServerConfigStore? _serverConfig;
  ApiClient? _api;
  TaskStore? _store;
  String? _email;
  String? _serverUrl;
  String? _initialError;
  bool _booting = true;
  bool _configuringServer = false;
  Locale? _locale;

  bool get _isNativePlatform => !kIsWeb;

  @override
  void initState() {
    super.initState();
    if (widget.demoMode) {
      _tokens = null;
      _localeStore = null;
      _api = null;
      _store = TaskStore.demo();
      _email = 'demo@cue.local';
      _booting = false;
    } else {
      _tokens = TokenStore();
      _localeStore = LocaleStore();
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _restoreLocale();
      if (_isNativePlatform) {
        _serverConfig = ServerConfigStore();
        final savedUrl = await _serverConfig!.serverUrl;
        final initialUrl = savedUrl?.trim().isNotEmpty == true
            ? savedUrl!
            : ApiClient.configuredBaseUrl;
        if (initialUrl.trim().isEmpty) {
          if (!mounted) return;
          setState(() {
            _booting = false;
            _configuringServer = true;
          });
          return;
        }
        _serverUrl = normalizeServerUrl(initialUrl);
        _api = ApiClient(_tokens!, baseUrl: _serverUrl);
      } else {
        _api = ApiClient(_tokens!);
        _serverUrl = _api!.serverUrl;
      }
      await _restore();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _booting = false;
        _initialError = error.toString();
        _configuringServer = _isNativePlatform && _api == null;
      });
    }
  }

  Future<void> _restoreLocale() async {
    try {
      final languageCode = await _localeStore!.languageCode;
      if (languageCode != null && mounted) {
        setState(() => _locale = Locale(languageCode));
      }
    } catch (_) {
      // A locale preference should never prevent the app from starting.
    }
  }

  void _changeLocale(Locale? locale) {
    setState(() => _locale = locale);
    final store = _localeStore;
    if (store != null) {
      unawaited(store.save(locale?.languageCode).catchError((_) {}));
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
      await _api!.logout();
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

  void _beginServerConfiguration() {
    setState(() {
      _configuringServer = true;
      _initialError = null;
    });
  }

  Future<void> _configureServer(String input) async {
    final serverUrl = normalizeServerUrl(input);
    final candidate = ApiClient(_tokens!, baseUrl: serverUrl);
    await candidate.checkConnection();
    await _serverConfig!.save(serverUrl);

    if (serverUrl == _serverUrl) {
      if (!mounted) return;
      setState(() {
        _configuringServer = false;
        _initialError = null;
      });
      return;
    }

    await _tokens.clear();
    if (!mounted) return;
    setState(() {
      _store?.dispose();
      _store = null;
      _email = null;
      _api = candidate;
      _serverUrl = serverUrl;
      _configuringServer = false;
      _initialError = null;
      _booting = false;
    });
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final home = _booting
        ? const _BootScreen()
        : _configuringServer
        ? ServerConnectionScreen(
            initialUrl: _serverUrl,
            onConnect: _configureServer,
            onCancel: _serverUrl == null
                ? null
                : () => setState(() => _configuringServer = false),
          )
        : _store == null
        ? LoginScreen(
            onLogin: _login,
            initialError: _initialError,
            serverUrl: _isNativePlatform ? _serverUrl : null,
            onChangeServer: _isNativePlatform
                ? _beginServerConfiguration
                : null,
          )
        : CueHome(
            store: _store!,
            userEmail: _email,
            onLogout: widget.demoMode ? null : _logout,
            serverUrl: _isNativePlatform ? _serverUrl : null,
            onConfigureServer: _isNativePlatform
                ? _beginServerConfiguration
                : null,
          );
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: CueTheme.active,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => CueLocaleScope(
        locale: _locale,
        onLocaleChanged: _changeLocale,
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
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
