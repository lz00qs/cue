import 'app_storage.dart';

class LocaleStore {
  LocaleStore({AppStorage? storage}) : _storage = storage ?? createAppStorage();

  static const _languageCodeKey = 'cue_language_code';
  static const supportedLanguageCodes = {'en', 'zh'};

  final AppStorage _storage;

  Future<String?> get languageCode async {
    final value = await _storage.read(key: _languageCodeKey);
    return supportedLanguageCodes.contains(value) ? value : null;
  }

  Future<void> save(String? languageCode) {
    if (languageCode == null) {
      return _storage.delete(key: _languageCodeKey);
    }
    if (!supportedLanguageCodes.contains(languageCode)) {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    return _storage.write(key: _languageCodeKey, value: languageCode);
  }
}
