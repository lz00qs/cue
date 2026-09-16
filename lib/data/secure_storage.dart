import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

FlutterSecureStorage createSecureStorage() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    // Cue does not share keychain items with other apps. The legacy macOS
    // keychain works with local ad-hoc signing without Keychain Sharing.
    return const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    );
  }
  return const FlutterSecureStorage();
}
