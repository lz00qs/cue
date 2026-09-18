import 'app_storage.dart';

class ThemeStore {
  ThemeStore({AppStorage? storage}) : _storage = storage ?? createAppStorage();

  static const _themeKey = 'cue_theme';
  final AppStorage _storage;

  Future<String?> get mode async {
    final value = await _storage.read(key: _themeKey);
    return value == 'light' || value == 'dark' ? value : null;
  }

  Future<void> save(String mode) {
    if (mode != 'light' && mode != 'dark') {
      throw ArgumentError.value(mode, 'mode');
    }
    return _storage.write(key: _themeKey, value: mode);
  }
}
