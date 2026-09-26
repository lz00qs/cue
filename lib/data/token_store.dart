import 'package:flutter/foundation.dart';
import 'app_storage.dart';

class TokenStore {
  TokenStore({AppStorage? storage}) : _storage = storage ?? createAppStorage();

  static const _accessKey = 'cue_access_token';
  static const _refreshKey = 'cue_refresh_token';
  static const _emailKey = 'cue_user_email';

  final AppStorage _storage;

  Future<String?> get accessToken async => kIsWeb ? null : await _storage.read(key: _accessKey);
  Future<String?> get refreshToken async => kIsWeb ? null : await _storage.read(key: _refreshKey);
  Future<String?> get email async => kIsWeb ? null : await _storage.read(key: _emailKey);

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String email,
  }) async {
    if (kIsWeb) return;
    // The web implementation lazily creates one encryption key. Serial writes
    // avoid racing that first key generation on a brand-new browser profile.
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _emailKey, value: email);
  }

  Future<void> clear() async {
    if (kIsWeb) return;
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _emailKey),
    ]);
  }
}
