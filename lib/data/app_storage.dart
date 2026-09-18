import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AppStorage {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

AppStorage createAppStorage() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    return const MacOsLocalStorage();
  }
  return _SecureAppStorage(const FlutterSecureStorage());
}

class MacOsLocalStorage implements AppStorage {
  const MacOsLocalStorage();

  static const channel = MethodChannel('top.hylcreative.cue/local_storage');

  @override
  Future<String?> read({required String key}) {
    return channel.invokeMethod<String>('read', {'key': key});
  }

  @override
  Future<void> write({required String key, required String value}) {
    return channel.invokeMethod<void>('write', {'key': key, 'value': value});
  }

  @override
  Future<void> delete({required String key}) {
    return channel.invokeMethod<void>('delete', {'key': key});
  }
}

class _SecureAppStorage implements AppStorage {
  const _SecureAppStorage(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
