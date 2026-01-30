import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/app_theme.dart';
import 'package:yamata_launcher/app_theme_dark.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/notifications_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/services/system_tray_service.dart';

void main(List<String> args) async {
  if (FileSystemService.isDesktop) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      skipTaskbar: false,
      minimumSize: Size(800, 800),
      fullScreen: args.contains("--fullscreen"),
      title: "Yamata Launcher",
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener, TrayListener {
  var showedTrayNotification = false;
  // Window overrides
  @override
  void onWindowClose() async {
    var closeToTray =
        await SettingsService().get<bool>(SettingsKeys.CLOSE_TO_SYSTEM_TRAY);
    if (closeToTray) {
      windowManager.hide();
      if (!showedTrayNotification) {
        await NotificationsService.showNotification(
          title: "Yamata Launcher",
          body:
              "Application is still running in the system tray. You can change this behavior in settings.",
        );
        showedTrayNotification = true;
      }
    } else {
      windowManager.destroy();
    }
  }

  // Tray overrides
  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    await SystemTrayService.handleTrayMenuItemClick(menuItem);
  }

  @override
  void onTrayIconMouseDown() async {
    await SystemTrayService.handleTrayIconClick();
  }

  @override
  void onTrayIconRightMouseDown() async {
    await SystemTrayService.handleTrayRightIconClick();
  }

  // Standard overrides
  @override
  void initState() {
    super.initState();
    windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>(
          create: (context) => AppProvider(),
        ),
        ChangeNotifierProvider<DownloadProvider>(
          create: (context) => DownloadProvider(),
        ),
        ChangeNotifierProvider<DownloadSourcesProvider>(
          create: (context) => DownloadSourcesProvider(),
        ),
        ChangeNotifierProvider<LibraryProvider>(
          create: (context) => LibraryProvider(),
        ),
      ],
      builder: (context, wg) {
        return ReactiveFormConfig(
          validationMessages: {
            ValidationMessage.required: (error) => 'Field must not be empty',
            ValidationMessage.email: (error) => 'Must enter a valid email',
            "url": (error) => 'Must enter a valid URL',
          },
          child: FilesystemPickerDefaultOptions(
            fileTileSelectMode: FileTileSelectMode.wholeTile,
            theme: FilesystemPickerTheme(
              topBar: FilesystemPickerTopBarThemeData(
                backgroundColor: appThemeDark.colorScheme.primary,
              ),
            ),
            child: Builder(builder: (context) {
              var appProvider = Provider.of<AppProvider>(context);
              return MaterialApp.router(
                  routerConfig: router,
                  title: 'Yamata Launcher',
                  themeMode: appProvider.themeMode,
                  theme: appThemeLight,
                  darkTheme: appThemeDark);
            }),
          ),
        );
      },
    );
  }
}
