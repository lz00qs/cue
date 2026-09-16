import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage.dart';

class LocaleStore {
  LocaleStore({FlutterSecureStorage? storage})
    : _storage = storage ?? createSecureStorage();

  static const _languageCodeKey = 'cue_language_code';
  static const supportedLanguageCodes = {'en', 'zh'};

  final FlutterSecureStorage _storage;

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
