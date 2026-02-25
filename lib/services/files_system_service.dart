import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:file_picker/file_picker.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/main.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/native/aria2c_android_interface.dart';
import 'package:yamata_launcher/services/native/intents_android_interface.dart';
import 'package:yamata_launcher/services/native/system_paths_android_interface.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';
import 'package:path/path.dart' as p;

class FileSystemService {
  static String _rootPath = "";
  static String _appSupportPath = "";
  static String? _downloadsPath;
  static SystemPaths? _systemPaths;
  static var isDesktop =
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  //getters
  static get rootPath {
    return _rootPath;
  }

  static get cachePath {
    return _appSupportPath + "/cache";
  }

  static get downloadsPath {
    if (_downloadsPath != null) {
      return _downloadsPath!;
    }
    return _rootPath + "/downloads";
  }

  static get portraitsPath {
    return cachePath + "/portraits";
  }

  static get notificationImagesPath {
    return cachePath + "/notification-images";
  }

  static get fetchCachePath {
    return cachePath + "/fetch-cache";
  }

  static get aria2cPath {
    if (Platform.isAndroid && Aria2cAndroidInterface.aria2cPath.isNotEmpty) {
      return Aria2cAndroidInterface.aria2cPath;
    }
    return (_appSupportPath ?? "") +
        "/aria2c/" +
        SystemHelpers.aria2cOutputBinary;
  }

  static get sevenZipPath {
    return (_appSupportPath ?? "") +
        "/7z/" +
        SystemHelpers.SevenZipOutputBinary;
  }

  static get torrentsCachePath {
    return cachePath + "/torrents";
  }

  static get downloadSourcesPath {
    return _appSupportPath + "/download-sources";
  }

  static get consoleSourcesPath {
    return _appSupportPath + "/console-sources";
  }

  static get databaseFilePath {
    return _appSupportPath + "/database.db";
  }

  static get downloadRegistryFilePath {
    return cachePath + "/downloads-neo.json";
  }

  static get emulatorIntentsFilePath {
    return _appSupportPath + "/emulator-intents.json";
  }

  static get updatesPath {
    return cachePath + "/updates";
  }

  static get webFilesPath {
    return cachePath + "/web";
  }

  /**
   * Shows a file system widget that its not a dialog, so it can be used on fullscreen mode. It returns the selected path or null if the user cancels the operation.
   */
  static Future<String?> _openBuiltInFilePicker(FilesystemType type,
      {List<String>? allowedExtensions}) async {
    var shortcuts = <FilesystemPickerShortcut>[];
    if (FileSystemService.isDesktop) {
      var loading = AlertsService.showLoadingAlert(
          navigatorContext!,
          "Loading drives...",
          "Please wait while we load the available drives.");
      var drives = await SystemHelpers.getAvailableDrives();
      loading.close();
      shortcuts = [
        FilesystemPickerShortcut(
            name: 'Home',
            path: Directory(Platform.isWindows ? "C:/" : "/"),
            icon: Icons.home),
        FilesystemPickerShortcut(
            name: 'Documents',
            path: await getApplicationDocumentsDirectory() ?? Directory("/"),
            icon: Icons.folder),
        FilesystemPickerShortcut(
            name: 'Downloads',
            path: Directory(downloadsPath) ??
                (await getDownloadsDirectory()) ??
                Directory("/"),
            icon: Icons.download),
        ...drives.map((drive) {
          return FilesystemPickerShortcut(
              name: drive, path: Directory(drive), icon: Icons.storage);
        })
      ];
    }
    if (Platform.isAndroid) {
      var internalDirectory = _systemPaths?.internalPath != null
          ? Directory(_systemPaths!.internalPath)
          : Directory("/storage/emulated/0/");
      shortcuts = [
        FilesystemPickerShortcut(
            name: 'Internal Card',
            path: internalDirectory,
            icon: Icons.phone_android),
        if (_systemPaths?.externalSdCardPath != null)
          FilesystemPickerShortcut(
              name: 'External Card',
              path: Directory(_systemPaths?.externalSdCardPath ?? ""),
              icon: Icons.sd_card),
        if (_systemPaths?.downloadsPath != null)
          FilesystemPickerShortcut(
              name: 'Downloads',
              path: Directory(_systemPaths?.downloadsPath ?? ""),
              icon: Icons.download),
      ];
    }
    var result = await FilesystemPicker.open(
      title:
          type == FilesystemType.folder ? 'Select a folder' : 'Select a file',
      context: navigatorContext!,
      fsType: type,
      pickText: type == FilesystemType.folder
          ? 'Select this folder'
          : 'Select this file',
      shortcuts: shortcuts,
      contextActions: [
        FilesystemPickerNewFolderContextAction(),
      ],
    );
    return result;
  }

  /**
   * Shows a file picker dialog and returns the selected file path. Returns null if the user cancels the dialog or an error occurs.
   *  if the app is in fullscreen mode, it falls back to a built in file system wrapper
   */
  static Future<String?> showFilePicker(
      {List<String>? allowedExtensions}) async {
    if (Platform.isAndroid) {
      if (!await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
      }
      return await _openBuiltInFilePicker(FilesystemType.file,
          allowedExtensions: allowedExtensions);
    }
    try {
      if (isFullScreen) {
        return await _openBuiltInFilePicker(FilesystemType.file,
            allowedExtensions: allowedExtensions);
      }
      final selectedFiles =
          await FilePicker.platform.pickFiles(type: FileType.any);
      if (selectedFiles == null || selectedFiles.files.isEmpty) return null;
      return selectedFiles.files.first.path!;
    } catch (e) {
      return _openBuiltInFilePicker(FilesystemType.file,
          allowedExtensions: allowedExtensions);
    }
  }

  /**
  * Shows a folder picker dialog and returns the selected folder path. Returns null if the user cancels the dialog or an error occurs.
  */
  static Future<String?> showFolderPicker() async {
    try {
      if (isFullScreen) {
        return await _openBuiltInFilePicker(FilesystemType.folder);
      }
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory == null) return null;
      return selectedDirectory;
    } catch (e) {
      return _openBuiltInFilePicker(FilesystemType.folder);
    }
  }

  /**
   * Opens the file explorer at the folder containing the specified file.
   */
  static Future openFileFolder(String filePath) async {
    final fileFolder = p.dirname(filePath);

    if (fileFolder.isEmpty) return;
    if (Platform.isAndroid) {
      var intentUri = await IntentsAndroidInterface.getIntentUri(fileFolder);
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: intentUri,
        flags: <int>[
          0x10000000,
          0x00000001,
        ],
        type: 'vnd.android.document/directory',
      );

      await intent.launch();
    } else {
      final uri = Uri.file(fileFolder);
      if (!await launchUrl(uri)) {
        throw Exception('Failed to open folder $fileFolder');
      }
    }
  }

  /**
   * Tests if the specified directory is writable and readable.
   */
  static bool testDirectory(String path) {
    try {
      var dir = Directory(path);
      if (dir.existsSync()) {
        var testFile = File(p.join(path, "test"));
        testFile.writeAsStringSync("test");
        var content = testFile.readAsStringSync();
        testFile.deleteSync();
        return content == "test";
      }
      return false;
    } catch (e) {
      print("Error testing directory: " + e.toString());
      return false;
    }
  }

  /*
  * Moves the content of the specified file to its containing folder.
  */
  static ContentMoveResult moveFilesToParentFolder(
    String folderPath, {
    String? filePath,
  }) {
    final sourceDir = Directory(folderPath);

    if (!sourceDir.existsSync()) {
      throw Exception("Folder does not exist: $folderPath");
    }

    final parentPath = sourceDir.parent.path;

    final items = sourceDir.listSync();

    for (final item in items) {
      final name = p.basename(item.path);
      var newPath = p.join(parentPath, name);
      if (item.path.endsWith(".aria2") ||
          item.path.endsWith(DOWNLOAD_MARK_FILENAME)) {
        item.deleteSync();
        continue;
      }
      item.renameSync(newPath);
    }

    try {
      sourceDir.deleteSync(recursive: true);
    } catch (_) {}

    if (Platform.isAndroid) {
      try {
        MediaScanner.loadMedia(path: parentPath);
      } catch (_) {}
    }

    String? newFilePath;

    if (filePath != null) {
      newFilePath = filePath.replaceAll(folderPath, parentPath);
    }
    return ContentMoveResult(
      parentFolder: parentPath,
      filePath: newFilePath,
    );
  }

  /**
   * Flattens all files in a directory by moving them to the root of the directory.
   */
  static Future<void> flattenDirectoryFiles(String rootPath) async {
    final rootDir = Directory(rootPath);

    if (!await rootDir.exists()) {
      throw Exception("The directory doesnt exists: $rootPath");
    }

    final entities = rootDir.listSync(recursive: true, followLinks: false);

    for (final entity in entities) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        final targetPath = p.join(rootDir.path, fileName);

        // If its on root, skip
        if (p.dirname(entity.path) == rootDir.path) continue;

        var finalTargetPath = targetPath;
        var counter = 1;

        // Avoid overwriting files
        while (File(finalTargetPath).existsSync()) {
          final name = p.basenameWithoutExtension(fileName);
          final ext = p.extension(fileName);
          finalTargetPath = p.join(rootDir.path, '$name ($counter)$ext');
          counter++;
        }
        await entity.rename(finalTargetPath);
      }
    }
  }

  static setupDownloadsPath() async {
    var path = await SettingsService().get<String>(SettingsKeys.DOWNLOAD_PATH);
    if (path.isEmpty) {
      _downloadsPath = _systemPaths?.downloadsPath ??
          (await getDownloadsDirectory())?.path ??
          null;
      await SettingsService()
          .set<String>(SettingsKeys.DOWNLOAD_PATH, downloadsPath);
      return;
    }
    if (path.isNotEmpty) {
      if (Directory(path).existsSync()) {
        _downloadsPath = path;
        return;
      }
    }
  }

  static setupAndroidIntents() async {
    final file = File(emulatorIntentsFilePath);
    if (await file.exists()) {
      return;
    }
    final byteData = await rootBundle.load("assets/data/emulator-intents.json");
    final bytes = byteData.buffer.asUint8List();
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static setupAria2c() async {
    var aria2cDir = Directory("${_appSupportPath}/aria2c");
    final file = File("${aria2cDir.path}/${SystemHelpers.aria2cOutputBinary}");
    if (await file.exists()) {
      return;
    }
    if (aria2cDir.existsSync() == false) {
      await aria2cDir.create(recursive: true);
    }

    final byteData = await rootBundle
        .load("assets/bin/aria2c/${SystemHelpers.aria2cAssetBinary}");
    final bytes = byteData.buffer.asUint8List();
    await file.writeAsBytes(bytes, flush: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', file.path]);
    }

    return file.path;
  }

  static setupSevenZip() async {
    var sevenZipDir = Directory("${_appSupportPath}/7z");
    final file =
        File("${sevenZipDir.path}/${SystemHelpers.SevenZipOutputBinary}");
    if (await file.exists()) {
      return;
    }
    if (sevenZipDir.existsSync() == false) {
      await sevenZipDir.create(recursive: true);
    }

    final byteData = await rootBundle
        .load("assets/bin/7z/${SystemHelpers.SevenZipAssetBinary}");
    final bytes = byteData.buffer.asUint8List();
    await file.writeAsBytes(bytes, flush: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', file.path]);
    } else {
      const dllFileName = "7z.dll";
      final dllFile = File("${sevenZipDir.path}/$dllFileName");
      final byteData = await rootBundle.load("assets/bin/7z/$dllFileName");
      final bytes = byteData.buffer.asUint8List();
      await dllFile.writeAsBytes(bytes, flush: true);
    }

    return file.path;
  }

  static Future<bool> deleteCachePath() async {
    try {
      var dir = Directory(cachePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await dir.create();
      return true;
    } catch (e) {
      print("Error deleting cache path: " + e.toString());
      return false;
    }
  }

  //root-path initializer
  static _initRootPath() async {
    var rootPath = "";
    rootPath = Directory.current.path;
    _appSupportPath = (await getApplicationSupportDirectory()).path;
    _rootPath = rootPath;
  }

  static _initAndroidSystemPaths() async {
    if (!Platform.isAndroid) return;
    try {
      _systemPaths = await SystemPathsAndroidInterface.getSystemPaths();
    } catch (e) {
      print("Error getting system paths: " + e.toString());
    }
  }

  //initializer
  static initPaths() async {
    await _initAndroidSystemPaths();
    await _initRootPath();
    await setupDownloadsPath();
    if (isDesktop) {
      await setupAria2c();
      await setupSevenZip();
    }
    if (Platform.isAndroid) {
      await setupAndroidIntents();
    }

    var paths = [
      downloadsPath,
      cachePath,
      portraitsPath,
      torrentsCachePath,
      downloadSourcesPath,
      consoleSourcesPath,
      fetchCachePath,
      notificationImagesPath,
      updatesPath,
      webFilesPath,
    ];
    for (var path in paths) {
      if (!await Directory(path).exists()) {
        await Directory(path).create(recursive: true);
      }
    }
  }
}

class ContentMoveResult {
  final String parentFolder;
  final String? filePath;

  ContentMoveResult({
    required this.parentFolder,
    required this.filePath,
  });
}
