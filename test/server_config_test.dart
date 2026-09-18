import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/data/api_client.dart';
import 'package:cue/l10n/l10n.dart';
import 'package:cue/ui/language_menu.dart';
import 'package:cue/ui/login_screen.dart';
import 'package:cue/ui/server_connection_screen.dart';

void main() {
  test('normalizes self-hosted server addresses', () {
    expect(normalizeServerUrl('http://10.0.2.2:8080'), 'http://10.0.2.2:8080');
    expect(
      normalizeServerUrl('https://cue.example.com/api/'),
      'https://cue.example.com',
    );
    expect(
      normalizeServerUrl('https://example.com/cue/'),
      'https://example.com/cue',
    );
    expect(
      normalizeServerUrl('http://localhost:8080'),
      'http://localhost:8080',
    );
    expect(normalizeServerUrl('http://cue:8080'), 'http://cue:8080');
    expect(() => normalizeServerUrl('10.0.2.2:8080'), throwsFormatException);
    expect(() => normalizeServerUrl('localhost:8080'), throwsFormatException);
    expect(() => normalizeServerUrl('jaldjfoashfoash'), throwsFormatException);
    expect(
      () => normalizeServerUrl('ftp://example.com'),
      throwsFormatException,
    );
  });

  testWidgets('connect screen verifies a normalized server URL', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? connectedUrl;

    await tester.pumpWidget(
      _localizedApp(
        home: ServerConnectionScreen(
          onConnect: (serverUrl) async => connectedUrl = serverUrl,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('server-url-field')),
      'http://10.0.2.2:8080',
    );
    await tester.tap(find.byKey(const Key('server-connect-button')));
    await tester.pumpAndSettle();

    expect(connectedUrl, 'http://10.0.2.2:8080');
  });

  for (final (locale, requiredMessage, schemeMessage, invalidMessage) in [
    (
      const Locale('en'),
      'Enter a server URL',
      'Start with http:// or https://',
      'Enter a valid server URL',
    ),
    (const Locale('zh'), '请输入服务器地址', '请以 http:// 或 https:// 开头', '请输入有效的服务器地址'),
  ]) {
    testWidgets('server URL validation is concise in ${locale.languageCode}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _localizedApp(
          locale: locale,
          home: ServerConnectionScreen(onConnect: (_) async {}),
        ),
      );

      await tester.tap(find.byKey(const Key('server-connect-button')));
      await tester.pumpAndSettle();
      expect(find.text(requiredMessage), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('server-url-field')),
        'ftp://example.com',
      );
      await tester.tap(find.byKey(const Key('server-connect-button')));
      await tester.pumpAndSettle();
      expect(find.text(schemeMessage), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('server-url-field')),
        'http://',
      );
      await tester.tap(find.byKey(const Key('server-connect-button')));
      await tester.pumpAndSettle();
      expect(find.text(invalidMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (locale, unreachableMessage) in [
    (const Locale('en'), "Can't reach the server. Check the URL."),
    (const Locale('zh'), '无法连接服务器，请检查地址。'),
  ]) {
    testWidgets(
      'connection failure is shown by the field in ${locale.languageCode}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          _localizedApp(
            locale: locale,
            home: ServerConnectionScreen(
              onConnect: (_) async => throw const ServerConnectionException(
                ServerConnectionFailure.unreachable,
              ),
            ),
          ),
        );

        await tester.enterText(
          find.byKey(const Key('server-url-field')),
          'http://unreachable.local',
        );
        await tester.tap(find.byKey(const Key('server-connect-button')));
        await tester.pumpAndSettle();
        expect(find.text(unreachableMessage), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('server-url-field')),
          'http://another.local',
        );
        await tester.pumpAndSettle();
        expect(find.text(unreachableMessage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('an address without a scheme gets immediate feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        home: ServerConnectionScreen(onConnect: (_) async {}),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('server-url-field')),
      'jaldjfoashfoash',
    );
    await tester.pumpAndSettle();
    expect(find.text('请以 http:// 或 https:// 开头'), findsOneWidget);
  });

  testWidgets('login shows the connected server and change action', (
    tester,
  ) async {
    var changeRequested = false;
    await tester.pumpWidget(
      _localizedApp(
        home: LoginScreen(
          serverUrl: 'http://10.0.2.2:8080',
          onChangeServer: () => changeRequested = true,
          onLogin: (_, _) async {},
        ),
      ),
    );

    expect(find.text('http://10.0.2.2:8080'), findsOneWidget);
    await tester.tap(find.byKey(const Key('change-server-button')));
    expect(changeRequested, isTrue);
  });
}

Widget _localizedApp({
  required Widget home,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => CueLocaleScope(
      locale: locale,
      onLocaleChanged: (_) {},
      child: child ?? const SizedBox.shrink(),
    ),
    home: home,
  );
}
