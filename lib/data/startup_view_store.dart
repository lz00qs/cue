import 'app_storage.dart';

enum StartupView { inbox, today, upcoming, list, calendar, quadrants }

class StartupViewStore {
  StartupViewStore({AppStorage? storage})
    : _storage = storage ?? createAppStorage();

  static const _startupViewKey = 'cue_startup_view';
  final AppStorage _storage;

  Future<StartupView?> get view async {
    final value = await _storage.read(key: _startupViewKey);
    for (final view in StartupView.values) {
      if (view.name == value) return view;
    }
    return null;
  }

  Future<void> save(StartupView view) {
    return _storage.write(key: _startupViewKey, value: view.name);
  }
}
