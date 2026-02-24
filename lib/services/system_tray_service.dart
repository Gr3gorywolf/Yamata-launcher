import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/providers/download_provider.dart';

class SystemTrayService {
  static _handleShowWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  static Future<void> _handleSetIcon() async {
    var iconPath =
        Platform.isWindows ? 'assets/icons/app.ico' : 'assets/images/logo.png';

    await trayManager.setIcon(iconPath);
  }

  static Future<void> initialize() async {
    await _handleSetIcon();
    await setupMenu();
    await updateTooltip();
  }

  static updateTooltip() {
    var downloadProvider =
        Provider.of<DownloadProvider>(navigatorContext!, listen: false);
    var downloadingCount = downloadProvider.activeDownloadInfos.length;
    const title = 'Yamata Launcher';
    try {
      if (downloadingCount > 0) {
        trayManager.setToolTip(
            '$title - $downloadingCount active tasks ${downloadProvider.totalDownloadPercent}% completed');
      } else {
        trayManager.setToolTip(title);
      }
    } catch (e) {
      print('Error updating tooltip: $e');
    }
  }

  static Future<void> setupMenu() async {
    Menu menu = Menu(items: [
      MenuItem(
        key: 'show',
        label: 'Open',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'explore',
        label: 'Explore',
      ),
      MenuItem(
        key: 'library',
        label: 'Library',
      ),
      MenuItem(
        key: 'downloads',
        label: 'Downloads',
      ),
      MenuItem(
        key: 'settings',
        label: 'Settings',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'exit',
        label: 'Exit',
      ),
    ]);
    await trayManager.setContextMenu(menu);
  }

  static Future<void> handleTrayRightIconClick() async {
    trayManager.popUpContextMenu();
  }

  static Future<void> handleTrayIconClick() async {
    _handleShowWindow();
  }

  static Future<void> handleTrayMenuItemClick(MenuItem menuItem) async {
    print('Tray menu item clicked: ${menuItem.key}');
    switch (menuItem.key) {
      case 'show':
        _handleShowWindow();
        break;
      case 'exit':
        await windowManager.destroy();
      case 'explore':
        _handleShowWindow();
        navigatorContext!.push('/explore');
        break;
      case 'library':
        _handleShowWindow();
        navigatorContext!.push('/library');
        break;
      case 'downloads':
        _handleShowWindow();
        navigatorContext!.push('/downloads');
        break;
      case 'settings':
        _handleShowWindow();
        navigatorContext!.push('/settings');
        break;
    }
  }
}
