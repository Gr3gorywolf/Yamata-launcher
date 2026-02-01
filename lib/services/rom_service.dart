import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:device_apps/device_apps.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:text_search/text_search.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/emulator_settings_dao.dart';
import 'package:yamata_launcher/database/daos/library_dao.dart';
import 'package:yamata_launcher/main.dart';
import 'package:yamata_launcher/models/emulator_intent.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/extraction_dialog.dart';
import 'package:yamata_launcher/utils/process_helper.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:yamata_launcher/utils/time_helpers.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

class RomService {
  static Future extractRom(RomLibraryItem downloadedRom) async {
    var resultFile = await ExtractionDialog.show(
        navigatorContext!, File(downloadedRom.filePath ?? ""));
    if (resultFile == null) {
      AlertsService.showErrorSnackbar("Failed to extract ROM from zip file.");
      return;
    }
    var provider =
        Provider.of<LibraryProvider>(navigatorContext!, listen: false);
    downloadedRom.filePath = resultFile.path;
    if (Platform.isAndroid) {
      MediaScanner.loadMedia(path: resultFile.path);
      MediaScanner.loadMedia(path: resultFile.parent.path);
    }
    provider.updateLibraryItem(downloadedRom);
    Future.microtask(() {
      AlertsService.showSnackbar("ROM extracted successfully!");
    });
  }

  static String normalizeRomTitle(String input, {bool deleteRunes = false}) {
    final buffer = StringBuffer();

    final cleaned =
        input.toLowerCase().replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '');
    if (deleteRunes == true) {
      return cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').trim();
    }
    for (final rune in cleaned.runes) {
      final mapped = StringHelper.unicodeMap[rune];
      if (mapped != null) {
        buffer.writeCharCode(mapped);
        continue;
      }

      if ((rune >= 97 && rune <= 122) || (rune >= 48 && rune <= 57)) {
        buffer.writeCharCode(rune);
      }
    }

    return buffer.toString();
  }

  static String getLastPlayedLabel(RomLibraryItem? downloadedRom) {
    if (downloadedRom == null) {
      return "Not installed";
    }

    if (downloadedRom.playTimeMins > 0) {
      return "⏱ Played ${TimeHelpers.formatMinutes(downloadedRom.playTimeMins.toInt())}";
    }

    if (downloadedRom.lastPlayedAt != null) {
      return "⏱ Last played ${TimeHelpers.getTimeAgo(downloadedRom.lastPlayedAt!)}";
    }

    if (downloadedRom.downloadedAt != null) {
      return "Installed ${TimeHelpers.getTimeAgo(downloadedRom.downloadedAt!)}";
    }

    if (downloadedRom.addedAt != null) {
      return "Added ${TimeHelpers.getTimeAgo(downloadedRom.addedAt!)}";
    }

    return "Not played yet";
  }

  /// Locate the largest valid ROM or compressed file in the given directory
  static File? searchRomFile(Directory directory,
      {bool skipCompressedFiles = false}) {
    String? outputPath;
    if (directory.existsSync()) {
      // Find the largest valid ROM / compressed file
      final validExtensions = {
        ...VALID_ROM_EXTENSIONS,
        ...(skipCompressedFiles ? [] : VALID_COMPRESSED_EXTENSIONS),
      }.map((e) => '.${e.toLowerCase()}').toSet();

      final files = directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) =>
              validExtensions.any((ext) => f.path.toLowerCase().endsWith(ext)))
          .toList();

      if (files.isNotEmpty) {
        files.sort(
          (a, b) => b.lengthSync().compareTo(a.lengthSync()),
        );

        var foundSetup = files.firstWhereOrNull((file) =>
            SETUP_FILE_NAMES.contains(p.basename(file.path).toLowerCase()));
        outputPath = foundSetup?.path ?? files.first.path;
      }
    }
    if (outputPath == null) {
      return null;
    }
    return File(outputPath);
  }
}
