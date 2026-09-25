import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

// Native handles must remain reachable for as long as their callbacks exist.
final List<Object> _trayResources = [];

Future<void> initSystemTray(void Function() requestCreateTask) async {
  if (kIsWeb) return;
  if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) return;
  if (_trayResources.isNotEmpty) return;

  await windowManager.ensureInitialized();

  final trayIcon = TrayIcon.create();
  final image = ImageAsset.fromAsset('web/icons/tray_icon.png');
  final menu = Menu.create();
  final createTaskItem = MenuItem.createWithLabelAndType(
    '创建 task',
    MenuItemType.normal,
  );
  final openCueItem = MenuItem.createWithLabelAndType(
    '打开 cue',
    MenuItemType.normal,
  );
  final exitCueItem = MenuItem.createWithLabelAndType(
    '退出 cue',
    MenuItemType.normal,
  );
  if (trayIcon == null ||
      image == null ||
      menu == null ||
      createTaskItem == null ||
      openCueItem == null ||
      exitCueItem == null) {
    debugPrint('Unable to initialize the system tray');
    return;
  }

  _trayResources.addAll([
    trayIcon,
    image,
    menu,
    createTaskItem,
    openCueItem,
    exitCueItem,
  ]);

  trayIcon.icon = image;
  menu.addItem(createTaskItem);
  menu.addItem(openCueItem);
  menu.addItem(exitCueItem);
  // nativeapi sends clicks to MenuItem, not to its parent Menu.
  createTaskItem.addListener((event) {
    if (event is MenuItemClickedEvent) {
      unawaited(_showCue(createTask: requestCreateTask));
    }
  });
  openCueItem.addListener((event) {
    if (event is MenuItemClickedEvent) {
      unawaited(_showCue());
    }
  });
  exitCueItem.addListener((event) {
    if (event is MenuItemClickedEvent) {
      exit(0);
    }
  });

  trayIcon.addListener((event) {
    if (event is TrayIconRightClickedEvent ||
        (Platform.isMacOS && event is TrayIconClickedEvent)) {
      trayIcon.openContextMenu();
    } else if (event is TrayIconClickedEvent) {
      unawaited(_showCue());
    }
  });
  trayIcon.setContextMenu(menu);
}

Future<void> _showCue({void Function()? createTask}) async {
  await windowManager.show();
  await windowManager.focus();
  createTask?.call();
}
