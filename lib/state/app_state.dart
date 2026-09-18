import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/locale_store.dart';
import '../data/server_config_store.dart';
import '../data/task_store.dart';
import '../data/theme_store.dart';
import '../data/token_store.dart';
import '../ui/cue_theme.dart';

final demoModeProvider = Provider<bool>((ref) => false);

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

final taskStoreProvider = Provider<TaskStore?>((ref) {
  return ref.watch(appControllerProvider.select((value) => value.store));
});

// TaskStore keeps the existing optimistic sync logic. Riverpod owns its
// subscription, so pages can watch updates without attaching Flutter listeners.
final taskRevisionProvider = StreamProvider<int>((ref) {
  final store = ref.watch(taskStoreProvider);
  if (store == null) return Stream.value(0);
  return Stream<int>.multi((controller) {
    var revision = 0;
    controller.add(revision);
    void changed() => controller.add(++revision);
    store.addListener(changed);
    controller.onCancel = () => store.removeListener(changed);
  });
});

class AppState {
  const AppState({
    this.store,
    this.email,
    this.serverUrl,
    this.initialError,
    this.booting = true,
    this.configuringServer = false,
    this.locale,
    this.themeMode = ThemeMode.light,
  });

  final TaskStore? store;
  final String? email;
  final String? serverUrl;
  final String? initialError;
  final bool booting;
  final bool configuringServer;
  final Locale? locale;
  final ThemeMode themeMode;

  static const _unchanged = Object();

  AppState copyWith({
    Object? store = _unchanged,
    Object? email = _unchanged,
    Object? serverUrl = _unchanged,
    Object? initialError = _unchanged,
    bool? booting,
    bool? configuringServer,
    Object? locale = _unchanged,
    ThemeMode? themeMode,
  }) => AppState(
    store: identical(store, _unchanged) ? this.store : store as TaskStore?,
    email: identical(email, _unchanged) ? this.email : email as String?,
    serverUrl: identical(serverUrl, _unchanged)
        ? this.serverUrl
        : serverUrl as String?,
    initialError: identical(initialError, _unchanged)
        ? this.initialError
        : initialError as String?,
    booting: booting ?? this.booting,
    configuringServer: configuringServer ?? this.configuringServer,
    locale: identical(locale, _unchanged) ? this.locale : locale as Locale?,
    themeMode: themeMode ?? this.themeMode,
  );
}

class AppController extends Notifier<AppState> {
  TokenStore? _tokens;
  LocaleStore? _localeStore;
  ThemeStore? _themeStore;
  ServerConfigStore? _serverConfig;
  ApiClient? _api;
  TaskStore? _activeStore;

  bool get _isNativePlatform => !kIsWeb;

  @override
  AppState build() {
    final defaultMode = CueColors.defaultMode == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    CueColors.isDark = defaultMode == ThemeMode.dark;
    ref.onDispose(() => _activeStore?.dispose());
    if (ref.read(demoModeProvider)) {
      _activeStore = TaskStore.demo();
      return AppState(
        store: _activeStore,
        email: 'demo@cue.local',
        booting: false,
        themeMode: defaultMode,
      );
    }
    _tokens = TokenStore();
    _localeStore = LocaleStore();
    _themeStore = ThemeStore();
    Future.microtask(_bootstrap);
    return AppState(themeMode: defaultMode);
  }

  Future<void> _bootstrap() async {
    try {
      await _restoreTheme();
      await _restoreLocale();
      if (_isNativePlatform) {
        _serverConfig = ServerConfigStore();
        final savedUrl = await _serverConfig!.serverUrl;
        final initialUrl = savedUrl?.trim().isNotEmpty == true
            ? savedUrl!
            : ApiClient.configuredBaseUrl;
        if (initialUrl.trim().isEmpty) {
          if (!ref.mounted) return;
          state = state.copyWith(booting: false, configuringServer: true);
          return;
        }
        final serverUrl = normalizeServerUrl(initialUrl);
        _api = ApiClient(_tokens!, baseUrl: serverUrl);
        if (ref.mounted) state = state.copyWith(serverUrl: serverUrl);
      } else {
        _api = ApiClient(_tokens!);
        if (ref.mounted) state = state.copyWith(serverUrl: _api!.serverUrl);
      }
      await _restore();
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        booting: false,
        initialError: error.toString(),
        configuringServer: _isNativePlatform && _api == null,
      );
    }
  }

  Future<void> _restoreLocale() async {
    try {
      final languageCode = await _localeStore!.languageCode;
      if (languageCode != null && ref.mounted) {
        state = state.copyWith(locale: Locale(languageCode));
      }
    } catch (_) {
      // A locale preference should never prevent the app from starting.
    }
  }

  Future<void> _restoreTheme() async {
    try {
      final mode = await _themeStore!.mode;
      if (mode != null && ref.mounted) {
        changeTheme(
          mode == 'dark' ? ThemeMode.dark : ThemeMode.light,
          persist: false,
        );
      }
    } catch (_) {
      // A theme preference should never prevent the app from starting.
    }
  }

  void changeTheme(ThemeMode mode, {bool persist = true}) {
    CueColors.isDark = mode == ThemeMode.dark;
    state = state.copyWith(themeMode: mode);
    final store = _themeStore;
    if (persist && store != null) {
      unawaited(
        store
            .save(mode == ThemeMode.dark ? 'dark' : 'light')
            .catchError((_) {}),
      );
    }
  }

  void changeLocale(Locale? locale) {
    state = state.copyWith(locale: locale);
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
      if (!ref.mounted) return;
      state = state.copyWith(
        booting: false,
        initialError: error is ApiException && error.statusCode != 401
            ? error.message
            : null,
      );
    }
  }

  Future<void> login(String email, String password) async {
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
    if (!ref.mounted) {
      store.dispose();
      return;
    }
    _activeStore?.dispose();
    _activeStore = store;
    state = state.copyWith(
      store: store,
      email: email,
      initialError: null,
      booting: false,
    );
  }

  Future<void> logout() async {
    await _api?.logout();
    if (!ref.mounted) return;
    _activeStore?.dispose();
    _activeStore = null;
    state = state.copyWith(store: null, email: null, initialError: null);
  }

  void beginServerConfiguration() {
    state = state.copyWith(configuringServer: true, initialError: null);
  }

  void cancelServerConfiguration() {
    state = state.copyWith(configuringServer: false);
  }

  Future<void> configureServer(String input) async {
    final serverUrl = normalizeServerUrl(input);
    final candidate = ApiClient(_tokens!, baseUrl: serverUrl);
    await candidate.checkConnection();
    await _serverConfig!.save(serverUrl);
    if (serverUrl == state.serverUrl) {
      if (!ref.mounted) return;
      state = state.copyWith(configuringServer: false, initialError: null);
      return;
    }
    await _tokens!.clear();
    if (!ref.mounted) return;
    _activeStore?.dispose();
    _activeStore = null;
    _api = candidate;
    state = state.copyWith(
      store: null,
      email: null,
      serverUrl: serverUrl,
      configuringServer: false,
      initialError: null,
      booting: false,
    );
  }
}
