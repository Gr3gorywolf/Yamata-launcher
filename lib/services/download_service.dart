import 'dart:io';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/download_history_dao.dart';
import 'package:yamata_launcher/database/daos/download_tasks_dao.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:provider/provider.dart';
import 'aria2c/aria2c_download_manager.dart';
import 'package:path/path.dart' as path;

class DownloadService {
  static initDownloadHistory() async {
    var downloadProvider =
        Provider.of<DownloadProvider>(navigatorContext!, listen: false);
    var downloadHistory = await DownloadHistoryDao(db!).getLatests();
    downloadProvider.setDownloadHistory(downloadHistory);
    downloadProvider.restoreDownloadTasks();
  }

  static continueDownload(DownloadInfo download) async {
    if (download.sourceExtractableUrl == null) {
      return;
    }
    var loading = AlertsService.showLoadingAlert(
        navigatorContext!, "Resuming download", "Please wait...");

    String? directLink = null;
    var downloadUrl = null;
    for (var uri in [download.downloadUrl, download.sourceExtractableUrl]) {
      if (uri == null) continue;

      print("Checking if $uri is a direct download link...");
      var isDirectLink =
          await DownloadSourcesRepository().isDirectDownload(uri);
      if (isDirectLink) {
        directLink = uri;
        break;
      }
    }

    try {
      if (directLink == null) {
        downloadUrl = await DownloadSourcesRepository()
            .extractDirectDownloadUrl(download.sourceExtractableUrl!);
      } else {
        downloadUrl = directLink;
      }
    } catch (e) {
      print("Error extracting direct download URL: $e");
    }

    loading.close();
    if (downloadUrl == null) {
      AlertsService.showErrorSnackbar(
          "Failed to resume download, please try again or start a new one.");
      return;
    }
    var downloadProvider =
        Provider.of<DownloadProvider>(navigatorContext!, listen: false);
    var task = await DownloadTasksDao(db!).get(download);
    if (task == null) {
      return;
    }
    var handle = await Aria2cDownloadManager.startDownload(
        rom: task.download.romInfo!,
        source: task.sourceRom,
        aria2cPath: FileSystemService.aria2cPath,
        selectedDownloadPath: task.download.downloadFolder);
    if (handle == null) {
      return;
    }
    downloadProvider.continueDownload(task, handle);
  }

  static deleteDownloadFolder(DownloadInfo download) async {
    if (download.downloadFolder != null) {
      var dir = Directory(download.downloadFolder!);
      var hasRegistry =
          File(path.join(dir.path, DOWNLOAD_MARK_FILENAME)).existsSync();
      if (await dir.exists() && hasRegistry) {
        await dir.delete(recursive: true);
      }
    }
  }

  static downloadRom(RomInfo rom, DownloadSourceRom sourceRom,
      {bool isExtraContent = false, bool shouldExtract = false}) async {
    var downloadsPath = FileSystemService.downloadsPath;
    if (!await Directory(downloadsPath).exists()) {
      await Directory(downloadsPath).create();
    }
    final handle = await Aria2cDownloadManager.startDownload(
      rom: rom,
      source: sourceRom,
      aria2cPath: FileSystemService.aria2cPath,
    );
    var contentTitle = sourceRom.title;
    Provider.of<DownloadProvider>(navigatorContext!, listen: false)
        .addRomDownloadToQueue(rom, sourceRom, handle,
            contentTitle: contentTitle,
            isExtraContent: isExtraContent,
            shouldExtract: shouldExtract);
  }
}
