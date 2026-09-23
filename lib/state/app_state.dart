import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/desktop_reminder_service.dart';
import '../data/locale_store.dart';
import '../data/server_config_store.dart';
import '../data/startup_view_store.dart';
import '../data/task_store.dart';
import '../data/theme_store.dart';
import '../data/token_store.dart';
import '../ui/cue_theme.dart';

final demoModeProvider = Provider<bool>((ref) => false);

final desktopReminderServiceProvider = Provider<DesktopReminderService>((ref) {
  final service = DesktopReminderService();
  ref.onDispose(service.dispose);
  return service;
});

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
    this.isInitialized = true,
    this.locale,
    this.themeMode = ThemeMode.system,
    this.startupView = StartupView.today,
    this.pendingReminderTaskId,
  });

  final TaskStore? store;
  final String? email;
  final String? serverUrl;
  final String? initialError;
  final bool booting;
  final bool configuringServer;
  final bool isInitialized;
  final Locale? locale;
  final ThemeMode themeMode;
  final StartupView startupView;
  final String? pendingReminderTaskId;

  static const _unchanged = Object();

  AppState copyWith({
    Object? store = _unchanged,
    Object? email = _unchanged,
    Object? serverUrl = _unchanged,
    Object? initialError = _unchanged,
    bool? booting,
    bool? configuringServer,
    bool? isInitialized,
    Object? locale = _unchanged,
    ThemeMode? themeMode,
    StartupView? startupView,
    Object? pendingReminderTaskId = _unchanged,
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
    isInitialized: isInitialized ?? this.isInitialized,
    locale: identical(locale, _unchanged) ? this.locale : locale as Locale?,
    themeMode: themeMode ?? this.themeMode,
    startupView: startupView ?? this.startupView,
    pendingReminderTaskId: identical(pendingReminderTaskId, _unchanged)
        ? this.pendingReminderTaskId
        : pendingReminderTaskId as String?,
  );
}

class AppController extends Notifier<AppState> with WidgetsBindingObserver {
  TokenStore? _tokens;
  LocaleStore? _localeStore;
  ThemeStore? _themeStore;
  StartupViewStore? _startupViewStore;
  ServerConfigStore? _serverConfig;
  ApiClient? _api;
  TaskStore? _activeStore;
  DesktopReminderService? _reminderService;

  bool get _isNativePlatform => !kIsWeb;
  DesktopReminderService? get reminderService => _reminderService;

  @override
  AppState build() {
    WidgetsBinding.instance.addObserver(this);
    _reminderService = ref.watch(desktopReminderServiceProvider);
    _reminderService?.onNotificationTap = _onNotificationTapped;

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _activeStore?.dispose();
    });

    final defaultMode = _parseThemeMode(CueColors.defaultMode);
    _applyThemeMode(defaultMode);

    if (ref.read(demoModeProvider)) {
      _activeStore = TaskStore.demo();
      _reminderService?.bind(_activeStore!);
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
    _startupViewStore = StartupViewStore();
    Future.microtask(_bootstrap);
    return AppState(themeMode: defaultMode);
  }

  @override
  void didChangePlatformBrightness() {
    if (state.themeMode == ThemeMode.system) {
      final newIsDark = _resolveIsDark(ThemeMode.system);
      if (CueColors.isDark != newIsDark) {
        CueColors.isDark = newIsDark;
        state = state.copyWith();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reminderService?.refresh();
    }
  }

  void _onNotificationTapped(String taskId) {
    if (!ref.mounted) return;
    state = state.copyWith(pendingReminderTaskId: taskId);
  }

  void consumePendingReminderTask() {
    if (state.pendingReminderTaskId == null) return;
    state = state.copyWith(pendingReminderTaskId: null);
  }

  static ThemeMode _parseThemeMode(String value) {
    return switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  static bool _resolveIsDark(ThemeMode mode) {
    if (mode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return mode == ThemeMode.dark;
  }

  void _applyThemeMode(ThemeMode mode) {
    CueColors.isDark = _resolveIsDark(mode);
  }

  Future<void> _bootstrap() async {
    try {
      await _restoreTheme();
      await _restoreLocale();
      await _restoreStartupView();
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
        _reminderService?.setLanguageCode(languageCode);
      }
    } catch (_) {
      // A locale preference should never prevent the app from starting.
    }
  }

  Future<void> _restoreTheme() async {
    try {
      final mode = await _themeStore!.mode;
      if (mode != null && ref.mounted) {
        changeTheme(_parseThemeMode(mode), persist: false);
      }
    } catch (_) {
      // A theme preference should never prevent the app from starting.
    }
  }

  Future<void> _restoreStartupView() async {
    try {
      final view = await _startupViewStore!.view;
      if (view != null && ref.mounted) {
        state = state.copyWith(startupView: view);
      }
    } catch (_) {
      // A startup view preference should never prevent the app from starting.
    }
  }

  void changeTheme(ThemeMode mode, {bool persist = true}) {
    _applyThemeMode(mode);
    state = state.copyWith(themeMode: mode);
    final store = _themeStore;
    if (persist && store != null) {
      final modeString = switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
      };
      unawaited(store.save(modeString).catchError((_) {}));
    }
  }

  void changeLocale(Locale? locale) {
    state = state.copyWith(locale: locale);
    _reminderService?.setLanguageCode(locale?.languageCode);
    final store = _localeStore;
    if (store != null) {
      unawaited(store.save(locale?.languageCode).catchError((_) {}));
    }
  }

  void changeStartupView(StartupView view) {
    state = state.copyWith(startupView: view);
    final store = _startupViewStore;
    if (store != null) {
      unawaited(store.save(view).catchError((_) {}));
    }
  }

  Future<void> _restore() async {
    try {
      final email = await _api!.restoreSession();
      await _openWorkspace(email);
    } catch (error) {
      if (!ref.mounted) return;
      var isInitialized = true;
      try {
        isInitialized = await _api!.checkInitStatus();
      } catch (_) {
        // If status check fails, fallback to default initialized state
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        booting: false,
        isInitialized: isInitialized,
        initialError: error is ApiException && error.statusCode != 401
            ? error.message
            : null,
      );
    }
  }

  Future<void> setupAdmin(String email, String password) async {
    final normalizedEmail = await _api!.setupAdmin(email, password);
    try {
      await _openWorkspace(normalizedEmail);
      if (!ref.mounted) return;
      state = state.copyWith(isInitialized: true);
    } catch (error) {
      await _api!.logout();
      rethrow;
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
    _reminderService?.bind(
      store,
      languageCode: state.locale?.languageCode,
    );
    state = state.copyWith(
      store: store,
      email: email,
      initialError: null,
      booting: false,
    );
  }

  Future<void> logout() async {
    await _api?.logout();
    await _reminderService?.clear();
    if (!ref.mounted) return;
    _activeStore?.dispose();
    _activeStore = null;
    state = state.copyWith(store: null, email: null, initialError: null);
  }

  Future<void> updateAccount({
    required String currentPassword,
    String? email,
    String? newPassword,
  }) async {
    final normalizedEmail = await _api!.updateAccount(
      currentPassword: currentPassword,
      email: email,
      newPassword: newPassword,
    );
    if (!ref.mounted) return;
    state = state.copyWith(email: normalizedEmail);
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
    bool isInitialized = true;
    try {
      isInitialized = await candidate.checkInitStatus();
    } catch (_) {}
    await _serverConfig!.save(serverUrl);
    if (serverUrl == state.serverUrl) {
      if (!ref.mounted) return;
      state = state.copyWith(
        configuringServer: false,
        isInitialized: isInitialized,
        initialError: null,
      );
      return;
    }
    await _tokens!.clear();
    await _reminderService?.clear();
    if (!ref.mounted) return;
    _activeStore?.dispose();
    _activeStore = null;
    _api = candidate;
    state = state.copyWith(
      store: null,
      email: null,
      serverUrl: serverUrl,
      configuringServer: false,
      isInitialized: isInitialized,
      initialError: null,
      booting: false,
    );
  }
}
