import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/download_history_dao.dart';
import 'package:yamata_launcher/models/download_history_item.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/aria2c/aria2c_client.dart';
import 'package:yamata_launcher/services/aria2c/aria2c_utils.dart';
import 'package:yamata_launcher/services/download_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/notifications_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:provider/provider.dart';
import "package:path/path.dart" as p;
import 'package:yamata_launcher/models/aria2c.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/services/extraction_service.dart';
import 'package:yamata_launcher/services/system_tray_service.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';

class _ActiveAria2Download {
  RomInfo? rom;
  DownloadSourceRom? source;
  Aria2DownloadHandle? handle;
  StreamSubscription? sub;

  _ActiveAria2Download({
    this.rom,
    this.source,
    this.handle,
    this.sub,
  });
}

class DownloadProvider extends ChangeNotifier {
  static DownloadProvider of(BuildContext ctx) {
    return Provider.of<DownloadProvider>(ctx);
  }

  static var _currentTaskbarProgressMode = TaskbarProgressMode.noProgress;
  final Map<String?, _ActiveAria2Download> _aria2cDownloadProcesses = {};
  final List<DownloadInfo> _activeDownloadInfos = [];
  final List<DownloadHistoryItem> _downloadHistory = [];

  List<DownloadInfo> get activeDownloadInfos => _activeDownloadInfos;
  List<DownloadHistoryItem> get downloadHistory => _downloadHistory
    ..sort((a, b) => b.downloadedAt!.compareTo(a.downloadedAt!));

  bool isRomDownloading(RomInfo rom) {
    return activeDownloadInfos.any((d) => d.romSlug == rom.slug);
  }

  double get totalDownloadPercent {
    if (_activeDownloadInfos.isEmpty) {
      return 0;
    }
    final total = _activeDownloadInfos.fold<int>(
        0,
        (previousValue, element) =>
            previousValue + (element.downloadPercent ?? 0));
    return total / _activeDownloadInfos.length;
  }

  DownloadInfo? getDownloadInfo(RomInfo? rom) {
    try {
      return _activeDownloadInfos.where((e) => e.romSlug == rom!.slug).first;
    } catch (_) {
      return null;
    }
  }

  DownloadInfo? getDownloadInfoBySlug(String? slug) {
    try {
      return _activeDownloadInfos.where((e) => e.romSlug == slug).first;
    } catch (_) {
      return null;
    }
  }

  Future setDownloadHistory(List<DownloadHistoryItem> history) async {
    _downloadHistory.clear();
    _downloadHistory.addAll(history);
    notifyListeners();
  }

  Future<void> addRomDownloadToQueue(
      RomInfo rom, DownloadSourceRom source, Aria2DownloadHandle handle,
      {bool isExtraContent = false, String? contentTitle}) async {
    final downloadId = handle.id;
    final info = DownloadInfo(
      romSlug: rom.slug,
      downloadId: downloadId,
      downloadPercent: 0,
      romInfo: rom,
      isExtraContent: isExtraContent,
      contentTitle: contentTitle,
      downloadInfo: 'Starting download...',
      totalSize: source.fileSize,
    );

    if (Platform.isAndroid) {
      NotificationsService.showNotification(
          title: 'Downloading ${rom.name}',
          body: 'Starting download...',
          image: rom.portrait,
          progressPercent: info.downloadPercent,
          tag: rom.slug,
          androidActions: [AndroidNotificationsActionTypes.CancelDownload]);
    }

    _activeDownloadInfos.add(info);
    final sub = handle.events!.listen((event) {
      _handleAria2Event(
        event,
        rom,
        source,
        handle,
        info,
      );
    });

    _aria2cDownloadProcesses[downloadId] = _ActiveAria2Download(
      rom: rom,
      source: source,
      handle: handle,
      sub: sub,
    );
    _handleProgressChanged();
    notifyListeners();
  }

  abortDownload(DownloadInfo info) async {
    if (info.isExtracting) {
      await ExtractionService.cancel(info.downloadId ?? "");
      if (Platform.isAndroid) {
        NotificationsService.cancelNotificationByTag(info.romSlug);
      }
      _activeDownloadInfos
          .removeWhere((element) => element.downloadId == info.downloadId);

      var libraryItem =
          Provider.of<LibraryProvider>(navigatorContext!, listen: false)
              .getLibraryItem(info.romSlug!);
      await _insertDownloadToHistory(info, libraryItem!.filePath!);
      notifyListeners();
      _handleProgressChanged();
      return;
    }
    final active = _aria2cDownloadProcesses[info.downloadId];
    if (active != null) {
      _activeDownloadInfos
          .removeWhere((element) => element.downloadId == info.downloadId);
      active.handle!.abort!(deleteFiles: !info.isExtraContent);
      _disposeActive(info.downloadId);
      if (Platform.isAndroid) {
        print("Cancelling notification for tag: ${info.romSlug}");
        NotificationsService.cancelNotificationByTag(info.romSlug);
      }
      notifyListeners();
      _handleProgressChanged();
    }
  }

  void _handleAria2Event(
    Aria2Event event,
    RomInfo rom,
    DownloadSourceRom source,
    Aria2DownloadHandle handle,
    DownloadInfo info,
  ) {
    if (event is Aria2ProgressEvent) {
      final p = event.progress;

      info.downloadPercent =
          int.tryParse(p.percent?.replaceAll('%', '') ?? '0');

      info.downloadInfo = Aria2cUtils.formatProgress(p);
      print("Download info: ${info.downloadInfo}");
      notifyListeners();
      _handleProgressChanged();
      if (Platform.isAndroid) {
        NotificationsService.showNotification(
          title: 'Downloading ${rom.name}',
          body: '${info.downloadInfo}',
          image: rom.portrait,
          progressPercent: info.downloadPercent,
          silent: true,
          tag: rom.slug,
          androidActions: [AndroidNotificationsActionTypes.CancelDownload],
        );
      }
      return;
    }

    if (event is Aria2LogEvent) {
      return;
    }

    if (event is Aria2DoneEvent) {
      info.downloadPercent = 100;
      info.downloadInfo = 'Download completed';
      print("Download completed: ${event.outputFilePath}");
      info.downloadPercent = 100;
      info.downloadInfo = 'Download completed';
      print("Download completed: ${event.outputFilePath}");
      _registerCompletedDownload(info, rom, event.outputFilePath ?? "");
      _disposeActive(handle.id);
      notifyListeners();
      return;
    }

    if (event is Aria2ErrorEvent) {
      info.downloadInfo = 'Error: ${event.message}';
      print("Download error: ${event.message}");
      _disposeActive(handle.id);
      Future.delayed(Duration(seconds: 2), () {
        _activeDownloadInfos.removeAt(_activeDownloadInfos.indexOf(info));
        notifyListeners();
        _handleProgressChanged();
        NotificationsService.showNotification(
          title: 'Failed to download ${rom.name}',
          body:
              '${StringHelper.truncateWithEllipsis(event.message ?? "Unknown error", 100)}',
          image: rom.portrait,
          tag: rom.slug,
        );
      });
    }
  }

  void _handleProgressChanged() {
    if (FileSystemService.isDesktop) {
      SystemTrayService.updateTooltip();
    }
    if (Platform.isWindows) {
      print("Updating taskbar progress...");
      if (_activeDownloadInfos.isEmpty) {
        WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress);
        WindowsTaskbar.setProgress(0, 0);
      } else {
        var isIndeterminate = totalDownloadPercent.toInt() < 1;
        var newStatus = isIndeterminate
            ? TaskbarProgressMode.indeterminate
            : TaskbarProgressMode.normal;
        if (newStatus != _currentTaskbarProgressMode) {
          WindowsTaskbar.setProgressMode(newStatus);
        }
        if (!isIndeterminate) {
          WindowsTaskbar.setProgress(totalDownloadPercent.toInt(), 100);
        }
      }
    }
  }

  _insertDownloadToHistory(DownloadInfo download, String path) async {
    var historyItem = DownloadHistoryItem.fromDownloadInfo(download,
        filePath: path,
        downloadedAt: DateTime.now(),
        downloadSize: download.totalSize);
    await DownloadHistoryDao(db!).insert(historyItem);
    _downloadHistory.add(historyItem);
    notifyListeners();
  }

  void _registerCompletedDownload(
      DownloadInfo download, RomInfo rom, String path) async {
    BuildContext? context = navigatorContext;
    if (context == null) {
      return;
    }
    var libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
    var libraryItem = libraryProvider.getLibraryItem(rom.slug);
    if (libraryItem == null) {
      libraryItem = RomLibraryItem(
        rom: rom,
        filePath: path,
        downloadedAt: DateTime.now(),
        addedAt: DateTime.now(),
      );
      await libraryProvider.addLibraryItem(libraryItem);
      return;
    }
    if (!download.isExtraContent) {
      libraryItem.filePath = path;
    }
    libraryItem.downloadedAt = DateTime.now();
    if (Platform.isAndroid) {
      MediaScanner.loadMedia(path: path);
      MediaScanner.loadMedia(path: File(path).parent.path);
    }
    await libraryProvider.updateLibraryItem(libraryItem);
    await NotificationsService.showNotification(
      title: 'Download completed',
      body:
          '${download.isExtraContent ? "Extra content for " : ""} ${rom.name} has been downloaded successfully.',
      image: rom.portrait,
      tag: rom.slug,
    );
    notifyListeners();
    _handleProgressChanged();
    var fileExtension = SystemHelpers.getFileExtension(path).toLowerCase();
    var extractionEnabled =
        await SettingsService().get<bool>(SettingsKeys.ENABLE_EXTRACTION);
    if (extractionEnabled == true &&
        VALID_COMPRESSED_EXTENSIONS.contains(fileExtension)) {
      _handleExtractRom(download, rom, path);
    } else {
      var newPath = await _handleMoveContentToParentFolder(libraryItem, path,
          updateLibrary: !download.isExtraContent);
      await _insertDownloadToHistory(download, newPath);
      _activeDownloadInfos.removeAt(_activeDownloadInfos.indexOf(download));
    }
  }

  void _handleExtractRom(
    DownloadInfo download,
    RomInfo rom,
    String path,
  ) async {
    final context = navigatorContext;
    if (context == null) return;

    final libraryProvider =
        Provider.of<LibraryProvider>(context, listen: false);

    final libraryItem = libraryProvider.getLibraryItem(download.romSlug);

    final file = File(path);
    final parentDir = file.parent;
    final (id, progressStream) = await ExtractionService.enqueueExtraction(
      input: file,
      output: parentDir,
      extractionId: download.downloadId,
      onError: (error) {
        _activeDownloadInfos.remove(download);
        notifyListeners();
      },
    );

    progressStream.listen((progress) {
      download.isExtracting = true;
      if (progress == -1) {
        _setExtractionQueuedState(download);
      } else {
        _setRomExtractionState(
          download: download,
          progress: progress,
          rom: rom,
        );
        if (progress >= 100) {
          _onExtractionEnded(
            download: download,
            rom: rom,
            zipFile: file,
            outputDir: parentDir,
            libraryItem: libraryItem,
            libraryProvider: libraryProvider,
          );
        }
      }

      notifyListeners();
    });
  }

  void _disposeActive(String? id) {
    final active = _aria2cDownloadProcesses.remove(id);
    active?.sub?.cancel();
  }

  void _setExtractionQueuedState(DownloadInfo download) {
    download.downloadPercent = 0;
    download.downloadInfo = "Queued for extraction...";
  }

  void _setRomExtractionState({
    required DownloadInfo download,
    required double progress,
    required RomInfo rom,
  }) {
    download.downloadPercent = progress.toInt();
    var progressLabel = progress > 0 ? progress.toStringAsFixed(1) + "%" : "";
    var state = progress > 0 ? "Extracting" : "Reading compressed file";
    download.downloadInfo = "${state}... ${progressLabel}";

    if (Platform.isAndroid) {
      if (progress >= 100) {
        NotificationsService.cancelNotificationByTag(rom.slug);
        return;
      }
      NotificationsService.showNotification(
          title: '${state} ${progress == 0 ? "for" : ""} ${rom.name}',
          body: download.downloadInfo ?? "",
          image: rom.portrait,
          silent: true,
          progressPercent: download.downloadPercent,
          tag: rom.slug,
          androidActions: [AndroidNotificationsActionTypes.CancelDownload]);
    }
    _handleProgressChanged();
  }

  void _onExtractionEnded({
    required DownloadInfo download,
    required RomInfo rom,
    required File zipFile,
    required Directory outputDir,
    required RomLibraryItem? libraryItem,
    required LibraryProvider libraryProvider,
  }) async {
    download.downloadPercent = 100;
    download.downloadInfo = "Extraction completed.";
    File? extractedFile =
        RomService.searchRomFile(outputDir, skipCompressedFiles: true);
    if (extractedFile != null) {
      if (Platform.isAndroid) {
        MediaScanner.loadMedia(path: extractedFile.path);
        MediaScanner.loadMedia(path: extractedFile.parent.path);
      }
      if (libraryItem != null && !download.isExtraContent) {
        libraryItem.filePath = extractedFile.path;
        libraryProvider.updateLibraryItem(libraryItem);
      }
      try {
        await zipFile.delete();
      } on Exception catch (e) {
        AlertsService.showErrorSnackbar(
            "Failed to delete zip file: ${e.toString()}",
            exception: e);
      }
      var newPath = await _handleMoveContentToParentFolder(
          libraryItem!, extractedFile.path,
          updateLibrary: !download.isExtraContent);
      await _insertDownloadToHistory(download, newPath);
    }

    NotificationsService.showNotification(
        title: download.downloadInfo ?? "",
        body: download.isExtraContent
            ? "Extra content for ${rom.name} extracted"
            : '${rom.name} is ready to play!',
        image: rom.portrait,
        tag: rom.slug,
        androidActions: [AndroidNotificationsActionTypes.PlayRomAction]);

    _activeDownloadInfos.remove(download);
    _handleProgressChanged();
    notifyListeners();
  }

  Future<String> _handleMoveContentToParentFolder(
      RomLibraryItem libraryItem, String path,
      {bool updateLibrary = true}) async {
    if (await SettingsService()
            .get<bool>(SettingsKeys.MOVE_ROMS_TO_NAMED_SUBFOLDER) ||
        PLATFORMS_WITH_DIRECTORY_TYPE_GAMES.contains(libraryItem.rom.console)) {
      return path;
    }
    try {
      var newPath = FileSystemService.moveFilesToParentFolder(path);

      if (updateLibrary) {
        libraryItem.filePath = newPath;
        Provider.of<LibraryProvider>(navigatorContext!, listen: false)
            .updateLibraryItem(libraryItem);
      }
      var parentFolder = Directory(p.dirname(path));
      try {
        parentFolder.deleteSync();
      } catch (e) {}
      return newPath;
    } catch (e) {
      print("Error moving files to containing folder: ${e.toString()}");
    }
    return path;
  }
}
