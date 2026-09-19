import 'package:flutter_test/flutter_test.dart';

import 'package:cue/data/app_storage.dart';
import 'package:cue/data/theme_store.dart';

class _MemoryStorage implements AppStorage {
  final values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

void main() {
  test('theme selection is saved and restored', () async {
    final storage = _MemoryStorage();
    final store = ThemeStore(storage: storage);
    expect(await store.mode, isNull);

    await store.save('dark');
    expect(await ThemeStore(storage: storage).mode, 'dark');

    await store.save('light');
    expect(await ThemeStore(storage: storage).mode, 'light');

    await store.save('system');
    expect(await ThemeStore(storage: storage).mode, 'system');

    storage.values['cue_theme'] = 'unexpected';
    expect(await store.mode, isNull);
    expect(() => store.save('invalid'), throwsArgumentError);
  });
}
