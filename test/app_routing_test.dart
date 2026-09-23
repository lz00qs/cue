import 'package:flutter_test/flutter_test.dart';

import 'package:cue/main.dart';

void main() {
  group('admin setup routing', () {
    test('shows setup on web when the workspace is not initialized', () {
      expect(shouldShowAdminSetup(isWeb: true, isInitialized: false), isTrue);
    });

    test('does not show setup on native platforms', () {
      expect(shouldShowAdminSetup(isWeb: false, isInitialized: false), isFalse);
      expect(shouldShowAdminSetup(isWeb: false, isInitialized: true), isFalse);
    });

    test('does not show setup after web initialization', () {
      expect(shouldShowAdminSetup(isWeb: true, isInitialized: true), isFalse);
    });
  });
}
