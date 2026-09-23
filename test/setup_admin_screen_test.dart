import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/data/api_client.dart';
import 'package:cue/l10n/generated/app_localizations.dart';
import 'package:cue/state/app_state.dart';
import 'package:cue/ui/setup_admin_screen.dart';

void main() {
  testWidgets(
    'renders SetupAdminScreen with all elements and localized strings',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _localizedApp(home: SetupAdminScreen(onSetup: (_, _) async {})),
      );

      expect(find.text('Initial Setup'), findsNothing);
      expect(find.text('Cue'), findsOneWidget);
      expect(find.byKey(const Key('setup-app-icon')), findsOneWidget);
      expect(find.text('Create Administrator Account'), findsOneWidget);
      expect(
        find.text(
          'Welcome to Cue. Create your administrator account to initialize the workspace.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('setup-email')), findsOneWidget);
      expect(find.byKey(const Key('setup-password')), findsOneWidget);
      expect(find.byKey(const Key('setup-confirm-password')), findsOneWidget);
      expect(find.byKey(const Key('setup-submit')), findsOneWidget);
      final emailField = tester.widget<TextFormField>(
        find.byKey(const Key('setup-email')),
      );
      expect(emailField.controller?.text, isEmpty);
      expect(find.text('Create Account & Sign In'), findsOneWidget);
      expect(
        find.text(
          'Your password is securely hashed in the database. No plaintext password is stored in .env.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders Chinese localization correctly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _localizedApp(
        locale: const Locale('zh'),
        home: SetupAdminScreen(onSetup: (_, _) async {}),
      ),
    );

    expect(find.text('初始设置'), findsNothing);
    expect(find.text('创建管理员账户'), findsOneWidget);
    expect(find.text('欢迎使用 Cue。请创建管理员账号以初始化工作区。'), findsOneWidget);
    expect(find.text('创建账号并登录'), findsOneWidget);
    expect(find.text('凭据已安全哈希并存储在数据库中，不会在本地 .env 文件中保存明文密码。'), findsOneWidget);
  });

  testWidgets('uses a branded split layout on wide screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _localizedApp(home: SetupAdminScreen(onSetup: (_, _) async {})),
    );

    expect(find.byKey(const Key('setup-brand-panel')), findsOneWidget);
    expect(find.byKey(const Key('setup-app-icon')), findsOneWidget);
    expect(find.text('Focus for today'), findsOneWidget);
    expect(find.byKey(const Key('setup-card')), findsOneWidget);
    final titleCenter = tester.getCenter(
      find.text('Create Administrator Account'),
    );
    final languageCenter = tester.getCenter(
      find.byKey(const Key('language-menu-button')),
    );
    expect((titleCenter.dy - languageCenter.dy).abs(), lessThan(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the setup form usable on narrow screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _localizedApp(home: SetupAdminScreen(onSetup: (_, _) async {})),
    );

    expect(find.byKey(const Key('setup-brand-panel')), findsNothing);
    expect(find.byKey(const Key('setup-app-icon')), findsOneWidget);
    expect(find.byKey(const Key('setup-email')), findsOneWidget);
    expect(find.byKey(const Key('setup-submit')), findsOneWidget);
    final iconCenter = tester.getCenter(
      find.byKey(const Key('setup-app-icon')),
    );
    final languageCenter = tester.getCenter(
      find.byKey(const Key('language-menu-button')),
    );
    expect((iconCenter.dy - languageCenter.dy).abs(), lessThan(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps medium browser windows in the compact layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _localizedApp(home: SetupAdminScreen(onSetup: (_, _) async {})),
    );

    expect(find.byKey(const Key('setup-brand-panel')), findsNothing);
    expect(find.byKey(const Key('setup-submit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validates required fields, password length and password match', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? submittedEmail;
    String? submittedPassword;

    await tester.pumpWidget(
      _localizedApp(
        home: SetupAdminScreen(
          onSetup: (email, password) async {
            submittedEmail = email;
            submittedPassword = password;
          },
        ),
      ),
    );

    // Clear email
    expect(isValidEmail('lz00qs@gmail.com'), isTrue);
    await tester.enterText(find.byKey(const Key('setup-email')), '');
    await tester.tap(find.byKey(const Key('setup-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(submittedEmail, isNull);

    // Enter malformed emails without valid domain/TLD
    for (final invalid in [
      'plainaddress',
      'admin@',
      'admin@cue',
      'admin@.local',
      'admin@cue..local',
    ]) {
      await tester.enterText(find.byKey(const Key('setup-email')), invalid);
      await tester.tap(find.byKey(const Key('setup-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a valid email'),
        findsOneWidget,
        reason: 'Failed for $invalid',
      );
      expect(submittedEmail, isNull);
    }

    // Enter valid email (with whitespace to verify trimming) and short password
    await tester.enterText(
      find.byKey(const Key('setup-email')),
      '  admin@cue.local  ',
    );
    await tester.enterText(find.byKey(const Key('setup-password')), '1234');
    await tester.tap(find.byKey(const Key('setup-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);

    // Enter valid password and mismatched confirm password
    await tester.enterText(
      find.byKey(const Key('setup-password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('setup-confirm-password')),
      'different123',
    );
    await tester.tap(find.byKey(const Key('setup-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);

    // Enter matching confirm password and submit
    await tester.enterText(
      find.byKey(const Key('setup-confirm-password')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('setup-submit')));
    await tester.pumpAndSettle();

    expect(submittedEmail, 'admin@cue.local');
    expect(submittedPassword, 'password123');
  });

  testWidgets('displays server URL and triggers change server callback', (
    tester,
  ) async {
    var changeServerCalled = false;
    await tester.pumpWidget(
      _localizedApp(
        home: SetupAdminScreen(
          onSetup: (_, _) async {},
          serverUrl: 'http://127.0.0.1:8080',
          onChangeServer: () => changeServerCalled = true,
        ),
      ),
    );

    expect(find.text('http://127.0.0.1:8080'), findsOneWidget);
    await tester.tap(find.byKey(const Key('change-server-button')));
    expect(changeServerCalled, isTrue);
  });

  testWidgets('displays initial error message', (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        home: SetupAdminScreen(
          onSetup: (_, _) async {},
          initialError: 'Server connection failed',
        ),
      ),
    );

    expect(find.text('Server connection failed'), findsOneWidget);
  });

  testWidgets(
    'supports switching language dynamically between English and Chinese',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: _TestAppView(home: SetupAdminScreen(onSetup: (_, _) async {})),
        ),
      );
      await tester.pumpAndSettle();

      // Default or initial: English
      expect(find.byKey(const Key('language-menu-button')), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Initial Setup'), findsNothing);
      expect(find.text('Create Administrator Account'), findsOneWidget);

      // Tap the language menu button
      await tester.tap(find.byKey(const Key('language-menu-button')));
      await tester.pumpAndSettle();

      // Select Chinese
      expect(find.byKey(const Key('language-option-zh')), findsOneWidget);
      await tester.tap(find.byKey(const Key('language-option-zh')));
      await tester.pumpAndSettle();

      // Verify Chinese strings are now rendered
      expect(find.text('中文'), findsWidgets);
      expect(find.text('初始设置'), findsNothing);
      expect(find.text('创建管理员账户'), findsOneWidget);
      expect(find.text('Initial Setup'), findsNothing);

      // Switch back to English
      await tester.tap(find.byKey(const Key('language-menu-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('language-option-en')), findsOneWidget);
      await tester.tap(find.byKey(const Key('language-option-en')));
      await tester.pumpAndSettle();

      // Verify English strings are back
      expect(find.text('Create Administrator Account'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    },
  );
}

class _TestAppView extends ConsumerWidget {
  const _TestAppView({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appControllerProvider.select((s) => s.locale));
    return MaterialApp(
      locale: locale ?? const Locale('en'),
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

Widget _localizedApp({
  required Widget home,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: locale,
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
