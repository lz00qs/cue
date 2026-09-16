import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/data/api_client.dart';
import 'package:cue/ui/login_screen.dart';
import 'package:cue/ui/server_connection_screen.dart';

void main() {
  test('normalizes self-hosted server addresses', () {
    expect(normalizeServerUrl('10.0.2.2:8080'), 'http://10.0.2.2:8080');
    expect(
      normalizeServerUrl('https://cue.example.com/api/'),
      'https://cue.example.com',
    );
    expect(
      normalizeServerUrl('https://example.com/cue/'),
      'https://example.com/cue',
    );
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
      MaterialApp(
        home: ServerConnectionScreen(
          onConnect: (serverUrl) async => connectedUrl = serverUrl,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('server-url-field')),
      '10.0.2.2:8080',
    );
    await tester.tap(find.byKey(const Key('server-connect-button')));
    await tester.pumpAndSettle();

    expect(connectedUrl, 'http://10.0.2.2:8080');
  });

  testWidgets('login shows the connected server and change action', (
    tester,
  ) async {
    var changeRequested = false;
    await tester.pumpWidget(
      MaterialApp(
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
