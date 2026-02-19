import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/repository/emulator_intents_repository.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/native/seven_zip_android_interface.dart';
import 'package:yamata_launcher/services/native/aria2c_android_interface.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/notifications_service.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/services/system_tray_service.dart';
import 'package:yamata_launcher/services/update_service.dart';
import 'package:yamata_launcher/utils/animation_helper.dart';
import 'package:yamata_launcher/services/assets_service.dart';
import 'package:yamata_launcher/services/download_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';

class SplashcreenPage extends StatefulWidget {
  @override
  _SplashcreenPageState createState() => _SplashcreenPageState();
}

class _SplashcreenPageState extends State<SplashcreenPage> {
  @override
  void initState() {
    super.initState();
    initApp();
  }

  initApp() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Provider.of<AppProvider>(context, listen: false).setupTheme();
    await FileSystemService.initPaths();
    await initPlugins();
    await initDb();
    await ConsoleService.loadConsoleSources();

    if (Platform.isAndroid) {
      await FileSystemService.setupAndroidIntents();
      await EmulatorService.loadEmulatorIntents();
      await requestAndroidPermissions();
    }
    await Provider.of<LibraryProvider>(context, listen: false).init();
    await Provider.of<DownloadSourcesProvider>(context, listen: false)
        .initialize();
    await DownloadService.initDownloadHistory();
    UpdateService.initialize();
    RomService.initializeGameFilenames();
    Provider.of<AppProvider>(context, listen: false).setAppLoaded(true);
    context.replace("/explore");
  }

  Future initPlugins() async {
    await NotificationsService.init();
    if (Platform.isAndroid) {
      await Aria2cAndroidInterface.init();
    }
    if (FileSystemService.isDesktop) {
      await SystemTrayService.initialize();
    }
  }

  Future requestAndroidPermissions() async {
    if (!await Permission.storage.isGranted) {
      await Permission.storage.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: FadeOut(
      duration: Duration(milliseconds: 1000),
      manualTrigger: true,
      controller: (controller) => AnimationHelper.handleAnimation(controller),
      child: AssetsService.getSvgImage("logo-orig", size: 330),
    )));
  }
}
