import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage.dart';

class ServerConfigStore {
  ServerConfigStore({FlutterSecureStorage? storage})
    : _storage = storage ?? createSecureStorage();

  static const _serverUrlKey = 'cue_server_url';

  final FlutterSecureStorage _storage;

  Future<String?> get serverUrl => _storage.read(key: _serverUrlKey);

  Future<void> save(String serverUrl) {
    return _storage.write(key: _serverUrlKey, value: serverUrl);
  }

  Future<void> clear() => _storage.delete(key: _serverUrlKey);
}
