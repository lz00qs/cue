import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/data/api_client.dart';
import 'package:cue/l10n/generated/app_localizations.dart';
import 'package:cue/ui/cue_theme.dart';
import 'package:cue/ui/login_screen.dart';

void main() {
  testWidgets('starts with matching empty email and password fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      _localizedApp(home: LoginScreen(onLogin: (_, _) async {})),
    );

    final email = tester.widget<TextFormField>(
      find.byKey(const Key('login-email')),
    );
    final password = tester.widget<TextFormField>(
      find.byKey(const Key('login-password')),
    );

    expect(email.controller?.text, isEmpty);
    expect(password.controller?.text, isEmpty);
    expect(email.autovalidateMode, AutovalidateMode.onUserInteraction);
    expect(password.autovalidateMode, AutovalidateMode.onUserInteraction);
    final emailInput = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('login-email')),
        matching: find.byType(TextField),
      ),
    );
    final passwordInput = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(TextField),
      ),
    );
    expect(emailInput.decoration?.labelText, 'Email');
    expect(passwordInput.decoration?.labelText, 'Password');
  });

  testWidgets('blocks malformed email addresses before login', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var loginCount = 0;

    await tester.pumpWidget(
      _localizedApp(
        home: LoginScreen(
          onLogin: (_, _) async {
            loginCount += 1;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login-password')),
      'password123',
    );

    for (final invalid in [
      'plainaddress',
      'admin@cue',
      '.admin@cue.local',
      'admin..user@cue.local',
      'admin@cue..local',
    ]) {
      await tester.enterText(find.byKey(const Key('login-email')), invalid);
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a valid email'),
        findsOneWidget,
        reason: 'Failed for $invalid',
      );
      expect(loginCount, 0);
    }
  });

  testWidgets('submits a trimmed valid email address', (tester) async {
    String? submittedEmail;
    String? submittedPassword;

    await tester.pumpWidget(
      _localizedApp(
        home: LoginScreen(
          onLogin: (email, password) async {
            submittedEmail = email;
            submittedPassword = password;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('login-email')),
      '  admin@cue.local  ',
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(submittedEmail, 'admin@cue.local');
    expect(submittedPassword, 'password123');
  });

  test('validates email dot placement and local-part length', () {
    expect(isValidEmail('user.name@example.com'), isTrue);
    expect(isValidEmail('.user@example.com'), isFalse);
    expect(isValidEmail('user.@example.com'), isFalse);
    expect(isValidEmail('user..name@example.com'), isFalse);
    expect(isValidEmail('${'a' * 65}@example.com'), isFalse);
  });
}

Widget _localizedApp({required Widget home}) {
  return ProviderScope(
    child: MaterialApp(
      theme: CueTheme.active,
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}
