import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:diacritic/diacritic.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/repository/roms_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/ui/widgets/extraction_dialog.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:yamata_launcher/utils/time_helpers.dart';
import 'package:provider/provider.dart';
import 'package:characters/characters.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class RomService {
  static List<String> windowsGamesFileNames = [];
  static Future initializeGameFilenames() async {
    var repository = RomsRepository();
    var filenames = await repository.fetchWindowsExecutableNames();
    windowsGamesFileNames = filenames;
  }

  static Future extractRom(RomLibraryItem downloadedRom) async {
    var resultFile = await ExtractionDialog.show(
        navigatorContext!, File(downloadedRom.filePath ?? ""),
        onError: (downloadError) {
      AlertsService.showErrorSnackbar(
          "Failed to extract ROM from zip file. $downloadError");
    });
    if (resultFile == null) {
      return;
    }
    var loader = AlertsService.showLoadingAlert(
        navigatorContext!,
        "Processing files",
        "Please wait while the extracted files gets processed.");
    var filePath = resultFile.path;
    var provider =
        Provider.of<DownloadProvider>(navigatorContext!, listen: false);
    var libraryProvider =
        Provider.of<LibraryProvider>(navigatorContext!, listen: false);
    var markFile = File('${resultFile.parent.path}/$DOWNLOAD_MARK_FILENAME');
    var hasMark = await markFile.exists();
    if (hasMark) {
      var markContent = await markFile.readAsString();
      if (markContent == downloadedRom.rom.slug) {
        filePath = await provider.moveLibraryContentToParentFolder(
            downloadedRom, resultFile.path, resultFile.parent.path);
      }
    }

    downloadedRom.filePath = filePath;
    if (Platform.isAndroid) {
      try {
        MediaScanner.loadMedia(path: filePath);
        MediaScanner.loadMedia(path: File(filePath).parent.path);
      } catch (e) {
        print("Error loading media: ${e.toString()}");
      }
    }
    libraryProvider.updateLibraryItem(downloadedRom);
    loader.close();
    Future.microtask(() {
      AlertsService.showSnackbar("ROM extracted successfully!");
    });
  }

  static Future<bool> deleteRomFiles(RomLibraryItem downloadedRom) async {
    if (downloadedRom.filePath == null) {
      return false;
    }
    final file = File(downloadedRom.filePath!);
    if (!await file.exists()) return false;

    final romNameClean =
        StringHelper.removeInvalidPathCharacters(downloadedRom.rom.name);

    Directory? currentDir = file.parent;
    Directory? folderWithMark;

    Future<bool> hasMarkFile(Directory dir) async {
      final markFile = File('${dir.path}/$DOWNLOAD_MARK_FILENAME');
      return await markFile.exists();
    }

    while (true) {
      if (currentDir == null) {
        return false;
      }
      if (await hasMarkFile(currentDir)) {
        folderWithMark = currentDir;
        break;
      }

      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        break;
      }

      currentDir = parent;
    }

    if (folderWithMark != null) {
      final folderName = folderWithMark.path.split(Platform.pathSeparator).last;
      var markContent =
          await File('${folderWithMark.path}/$DOWNLOAD_MARK_FILENAME')
              .readAsString();
      if (folderName.contains(romNameClean) ||
          markContent == downloadedRom.rom.slug) {
        await folderWithMark.delete(recursive: true);
        return true;
      }
    }
    await file.delete();
    return true;
  }

  static String normalizeRomTitle(String input, {bool deleteRunes = false}) {
    var cleaned =
        input.toLowerCase().replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
    if (!deleteRunes) {
      cleaned = removeDiacritics(cleaned);
    }

    return cleaned.replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }

  static String getRomSlug(String consoleSlug, String romName,
      {bool removeMisplacedWords = false, bool removeDiacritics = true}) {
    var cleanRomName = removeMisplacedWords
        ? StringHelper.removeMisplacedWords(romName)
        : romName;
    return consoleSlug +
        "-" +
        normalizeRomTitle(cleanRomName, deleteRunes: removeDiacritics);
  }

  // Generate different slug variants to increase the chances of matching with scraped data
  static List<String> getSlugVariants(
      String consoleSlug, String romName, String originalSlug) {
    return [
      originalSlug,
      RomService.getRomSlug(consoleSlug, romName,
          removeMisplacedWords: true, removeDiacritics: true),
      RomService.getRomSlug(consoleSlug, romName,
          removeMisplacedWords: false, removeDiacritics: true),
      RomService.getRomSlug(consoleSlug, romName,
          removeMisplacedWords: true, removeDiacritics: true),
      RomService.getRomSlug(consoleSlug, romName,
          removeMisplacedWords: false, removeDiacritics: false)
    ].toSet().toList();
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
  static File? searchRomFile(
    Directory directory, {
    bool skipCompressedFiles = false,
    String? specificFileName,
  }) {
    if (!directory.existsSync()) return null;

    final validExtensions = {
      ...VALID_ROM_EXTENSIONS,
      if (!skipCompressedFiles) ...VALID_COMPRESSED_EXTENSIONS,
    }.map((e) => '.${e.toLowerCase()}').toSet();

    final invalidExecs = {
      ...REDIST_FILE_MATCHES,
      ...UNINSTS_FILE_NAMES,
    };

    final windowsExtensions = CONSOLE_EXTENSIONS.entries
        .where((entry) => entry.value.contains(CONSOLE_SLUGS.windows))
        .map((entry) => '.${entry.key}'.toLowerCase())
        .toSet();

    final files =
        directory.listSync(recursive: true).whereType<File>().where((f) {
      final pathLower = f.path.toLowerCase();
      final baseName = p.basename(pathLower);

      final hasValidExtension =
          validExtensions.any((ext) => pathLower.endsWith(ext));

      if (!hasValidExtension) return false;

      final isWindowsExec =
          windowsExtensions.any((ext) => pathLower.endsWith(ext));

      final isInvalidExec = isWindowsExec &&
          invalidExecs.any((invalid) => baseName.contains(invalid));

      return !isInvalidExec;
    }).toList();

    if (files.isEmpty) return null;

    files.sort((a, b) {
      final pathCompare = a.path.length.compareTo(b.path.length);
      if (pathCompare != 0) return pathCompare;

      return b.lengthSync().compareTo(a.lengthSync());
    });

    final priorityNames = [
      if (specificFileName != null) specificFileName.toLowerCase(),
      ...SETUP_FILE_NAMES,
      ...windowsGamesFileNames,
    ];

    final foundFilename = files.firstWhereOrNull((file) {
      final pathLower = file.path.toLowerCase();
      return priorityNames.any((name) => pathLower.endsWith(name));
    });

    final foundWindowsExec = files.firstWhereOrNull((file) {
      final pathLower = file.path.toLowerCase();
      return windowsExtensions.any((ext) => pathLower.endsWith(ext));
    });

    final output = foundFilename ?? foundWindowsExec ?? files.first;

    return File(output.path);
  }

  static Future catchRomPortrait(RomInfo romInfo,
      {bool shouldRegenerate = false}) async {
    var portraitName = '${FileSystemService.portraitsPath}/${romInfo.slug}.png';
    var portraitUrl = romInfo.portrait ?? '';
    if ((!File(portraitName).existsSync() || shouldRegenerate) &&
        portraitUrl.isNotEmpty) {
      try {
        var res = await http.get(Uri.parse(romInfo.portrait ?? ''));
        await File(portraitName).writeAsBytes(res.bodyBytes);
      } catch (e) {
        print("Error fetching portrait: ${e.toString()}");
        return;
      }
    }
  }

  static Future deleteRomPortraitCache(RomInfo romInfo) async {
    var portraitName = '${FileSystemService.portraitsPath}/${romInfo.slug}.png';
    if (File(portraitName).existsSync()) {
      File(portraitName).deleteSync();
    }
  }

  static Future<String> calculateCrc32(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw FileSystemException('File not found', path);
    }

    int crc = 0;

    await for (final chunk in file.openRead()) {
      crc = getCrc32(chunk, crc);
    }

    return crc.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase();
  }
}
