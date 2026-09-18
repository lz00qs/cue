import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cue/data/app_storage.dart';
import 'package:cue/data/locale_store.dart';
import 'package:cue/data/server_config_store.dart';
import 'package:cue/data/theme_store.dart';
import 'package:cue/data/token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'macOS stores the session and preferences through local app data',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final values = <String, String>{};
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MacOsLocalStorage.channel, (call) async {
            calls.add(call.method);
            final arguments = Map<String, String>.from(
              call.arguments as Map<dynamic, dynamic>,
            );
            final key = arguments['key']!;
            switch (call.method) {
              case 'read':
                return values[key];
              case 'write':
                values[key] = arguments['value']!;
                return null;
              case 'delete':
                values.remove(key);
                return null;
              default:
                throw MissingPluginException(call.method);
            }
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(MacOsLocalStorage.channel, null);
      });

      expect(createAppStorage(), isA<MacOsLocalStorage>());
      final tokens = TokenStore();
      final server = ServerConfigStore();
      final locale = LocaleStore();
      final theme = ThemeStore();
      await tokens.save(
        accessToken: 'access',
        refreshToken: 'refresh',
        email: 'user@example.com',
      );
      await server.save('https://cue.example.com');
      await locale.save('zh');
      await theme.save('dark');

      expect(await TokenStore().refreshToken, 'refresh');
      expect(await ServerConfigStore().serverUrl, 'https://cue.example.com');
      expect(await LocaleStore().languageCode, 'zh');
      expect(await ThemeStore().mode, 'dark');
      expect(
        values.keys,
        containsAll([
          'cue_access_token',
          'cue_refresh_token',
          'cue_user_email',
          'cue_server_url',
          'cue_language_code',
          'cue_theme',
        ]),
      );
      expect(calls, containsAll(['read', 'write']));

      await tokens.clear();
      expect(await TokenStore().refreshToken, isNull);
    },
  );
}
