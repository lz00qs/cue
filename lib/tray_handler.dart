import 'package:flutter/foundation.dart';

import 'tray_handler_stub.dart'
    if (dart.library.io) 'tray_handler_native.dart' as platform_tray;

// The native menu requests task creation only while CueHome is on screen.
final ValueNotifier<int> trayCreateTaskRequests = ValueNotifier<int>(0);

Future<void> initSystemTray() => platform_tray.initSystemTray(
  () => trayCreateTaskRequests.value++,
);
