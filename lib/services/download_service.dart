import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/download_history_dao.dart';
import 'package:yamata_launcher/models/aria2c.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';
import 'package:path/path.dart' as p;
import 'aria2c/aria2c_download_manager.dart';

class DownloadService {
  static initDownloadHistory() async {
    var downloadProvider =
        Provider.of<DownloadProvider>(navigatorContext!, listen: false);
    var downloadHistory = await DownloadHistoryDao(db!).getLatests();
    downloadProvider.setDownloadHistory(downloadHistory);
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

  static void catchRomPortrait(RomInfo romInfo) async {
    var portraitName = '${FileSystemService.portraitsPath}/${romInfo.slug}.png';
    var portraitUrl = romInfo.portrait ?? '';
    if (!File(portraitName).existsSync() && portraitUrl.isNotEmpty) {
      http.get(Uri.parse(romInfo.portrait ?? '')).then((response) {
        new File(portraitName).writeAsBytes(response.bodyBytes);
      });
    }
  }
}
