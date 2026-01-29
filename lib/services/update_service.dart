import 'dart:io';

import 'package:flutter_app_installer/flutter_app_installer.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/models/update_info.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/repository/update_repository.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/utils/file_download_fetch.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';

class UpdateService {
  static FileDownloadFetch? _currentDownload;
  static get currentDownload => _currentDownload;

  static Future<void> initialize() async {
    await cleanupOldDownloads();
    await checkForUpdate();
  }

  static Future cleanupOldDownloads() async {
    var updatesPath = FileSystemService.updatesPath;
    var updatesDir = Directory(updatesPath);
    if (await updatesDir.exists()) {
      var entities = updatesDir.listSync();
      var packageInfo = await PackageInfo.fromPlatform();
      var currentVersion = packageInfo.version;
      for (var entity in entities) {
        if (entity is Directory) {
          var dirName = entity.path.split(Platform.pathSeparator).last;
          if (!StringHelper.isVersionStringNewer(currentVersion, dirName)) {
            try {
              await entity.delete(recursive: true);
            } catch (e) {}
          }
        }
      }
    }
  }

  static Future<UpdateInfo?> checkForUpdate() async {
    var provider = Provider.of<AppProvider>(navigatorContext!, listen: false);
    var info = await UpdateRepository().fetchUpdateInfo();
    if (info == null) {
      return null;
    }

    if (await isUpdateNew(info)) {
      var updateFolder = "${FileSystemService.updatesPath}/${info.version}";
      var targetFile = "$updateFolder/${getUpdateFileName() ?? "update_file"}";
      var doneFile = File("$updateFolder/done");
      if (doneFile.existsSync() && File(targetFile).existsSync()) {
        info.downloadedFilePath = targetFile;
        info.progress = 100;
      }
      provider.setUpdateInfo(info);
      return info;
    }
    return null;
  }

  static Future<bool> isUpdateNew(UpdateInfo updateInfo) async {
    final packageInfo = await PackageInfo.fromPlatform();
    return StringHelper.isVersionStringNewer(
        packageInfo.version, updateInfo.version);
  }

  static String? getUpdateFileName() {
    if (Platform.isAndroid) {
      return "yamata-launcher.apk";
    }
    if (Platform.isLinux) {
      return "yamata-launcher-${SystemHelpers.isArm ? "arm" : "x86"}.AppImage";
    } else if (Platform.isWindows) {
      return "yamata-launcher-installer.exe";
    } else if (Platform.isMacOS) {
      return "yamata-launcher-installer.dmg";
    }
    return null;
  }

  static void _restartCurrentApp() {
    final exe = Platform.resolvedExecutable;

    Process.start(
      exe,
      [],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }

  static void cancelUpdateDownload() {
    var provider = Provider.of<AppProvider>(navigatorContext!, listen: false);
    if (provider.updateInfo == null) return;
    _currentDownload?.cancel();
    _currentDownload = null;
    var updateInfo = provider.updateInfo!;
    updateInfo.progress = null;
    provider.setUpdateInfo(updateInfo);
  }

  static startUpdateDownload() {
    var provider = Provider.of<AppProvider>(navigatorContext!, listen: false);
    if (provider.updateInfo == null) return;
    var updateInfo = provider.updateInfo!;
    var updateFolder = "${FileSystemService.updatesPath}/${updateInfo.version}";
    var targetFile = "$updateFolder/${getUpdateFileName() ?? "update_file"}";
    Directory(updateFolder).createSync(recursive: true);

    _currentDownload = FileDownloadFetch(
      url: Uri.parse(updateInfo.fileToDownload),
      onProgress: (int progress) {
        updateInfo.progress = progress;
        provider.setUpdateInfo(updateInfo);
        if (progress == 100) {
          var doneFile = File("$updateFolder/done");
          doneFile.writeAsStringSync("done");
          updateInfo.downloadedFilePath = targetFile;
          updateInfo.progress = 100;
          provider.setUpdateInfo(updateInfo);
        }
      },
      savePath: targetFile,
    );
    _currentDownload!.start().then((filePath) {}).catchError((error) {
      updateInfo.progress = null;
      provider.setUpdateInfo(updateInfo);
    });
  }

  static handleInstall() async {
    var provider = Provider.of<AppProvider>(navigatorContext!, listen: false);
    if (Platform.isWindows) {
      await Process.start(
        provider.updateInfo!.downloadedFilePath!,
        [],
        mode: ProcessStartMode.normal,
      );
    }

    if (Platform.isMacOS) {
      await Process.start(
        "open",
        [
          provider.updateInfo!.downloadedFilePath!,
        ],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    }

    if (Platform.isAndroid) {
      final FlutterAppInstaller flutterAppInstaller = FlutterAppInstaller();
      flutterAppInstaller.installApk(
        filePath: provider.updateInfo!.downloadedFilePath!,
      );
    }
  }
}
