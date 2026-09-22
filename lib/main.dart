import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/l10n.dart';
import 'state/app_state.dart';
import 'state/page_state.dart';
import 'ui/cue_home.dart';
import 'ui/cue_theme.dart';
import 'ui/login_screen.dart';
import 'ui/server_connection_screen.dart';

void main() {
  runApp(const CueApp());
}

class CueApp extends StatelessWidget {
  const CueApp({super.key}) : demoMode = false;
  const CueApp.demo({super.key}) : demoMode = true;

  final bool demoMode;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [demoModeProvider.overrideWithValue(demoMode)],
      child: const _CueAppView(),
    );
  }
}

class _CueAppView extends ConsumerWidget {
  const _CueAppView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final isNativePlatform = !kIsWeb;
    final home = app.booting
        ? const _BootScreen()
        : app.configuringServer
        ? ServerConnectionScreen(
            initialUrl: app.serverUrl,
            onConnect: controller.configureServer,
            onCancel: app.serverUrl == null
                ? null
                : controller.cancelServerConfiguration,
          )
        : app.store == null
        ? LoginScreen(
            onLogin: controller.login,
            initialError: app.initialError,
            serverUrl: isNativePlatform ? app.serverUrl : null,
            onChangeServer: isNativePlatform
                ? controller.beginServerConfiguration
                : null,
          )
        : ProviderScope(
            overrides: [
              initialStartupViewProvider.overrideWithValue(app.startupView),
            ],
            child: CueHome(
              userEmail: app.email,
              onLogout: ref.read(demoModeProvider) ? null : controller.logout,
              serverUrl: isNativePlatform ? app.serverUrl : null,
              onConfigureServer: isNativePlatform
                  ? controller.beginServerConfiguration
                  : null,
            ),
          );
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: CueTheme.active,
      locale: app.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
