import 'app_storage.dart';

class ServerConfigStore {
  ServerConfigStore({AppStorage? storage})
    : _storage = storage ?? createAppStorage();

  static const _serverUrlKey = 'cue_server_url';

  final AppStorage _storage;

  Future<String?> get serverUrl => _storage.read(key: _serverUrlKey);

  Future<void> save(String serverUrl) {
    return _storage.write(key: _serverUrlKey, value: serverUrl);
  }

  Future<void> clear() => _storage.delete(key: _serverUrlKey);
}
