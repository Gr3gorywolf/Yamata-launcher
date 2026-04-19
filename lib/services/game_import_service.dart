import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_metadata.dart';
import 'package:yamata_launcher/repository/roms_repository.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/widgets/rom_download_sources_dialog/rom_download_sources_dialog_confirm_dialog.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

typedef GameImportScanCallback = void Function(
  GameImportScanCallbackPayload payload,
);
typedef GameImportProgressCallback = void Function(
  GameImportProgressPayload payload,
);

class GameImportService {
  // 70mb
  static final double _MAX_ALLOWED_TO_READ = 7e+7;

  /// Performs a single-pass recursive scan over the selected folder.
  ///
  /// The scan uses a filesystem stream instead of materializing the full tree,
  /// which keeps memory usage low even on very large folders.
  static Future<void> scanForGames(
    String folderPath,
    GameImportScanCallback callback, {
    List<String>? filesToSkip,
    GameImportProgressCallback? onProgress,
    String? consoleFilter,
  }) async {
    var discoveredFiles = 0;
    var processedFiles = 0;

    _notifyProgress(
      onProgress,
      totalFiles: discoveredFiles,
      processedFiles: processedFiles,
    );

    await for (final filePath in _scanFilesRecursively(
      folderPath,
      filesToSkip: filesToSkip,
      consoleFilter: consoleFilter,
    )) {
      discoveredFiles += 1;
      var rom = _buildRomInfo(filePath);
      // Create Futures for each rom
      Future<RomInfo>(() async {
        if (rom.console == 'unknown' || rom.name == "unknown") {
          rom = await completeRomInfo(filePath);
        }
        return rom;
      }).then((rom) {
        callback(
          GameImportScanCallbackPayload(
            currentRom: rom,
            currentFile: filePath,
          ),
        );
        processedFiles += 1;
        _notifyProgress(
          onProgress,
          totalFiles: discoveredFiles,
          processedFiles: processedFiles,
        );
      });
    }
    while (processedFiles < discoveredFiles) {
      // In case the stream finished but some metadata lookups are still running,
      // keep the progress updated until all files gets processed.
      await Future.delayed(const Duration(seconds: 1));
      _notifyProgress(
        onProgress,
        totalFiles: discoveredFiles,
        processedFiles: processedFiles,
      );
    }
  }

  /// Tries to complete the rom info with multiple strategies, starting with the less expensive ones (filename-based) and going up to more expensive ones (crc-based).
  static Future<RomInfo> completeRomInfo(String filePath) async {
    final extension = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    final inferredConsoles = CONSOLE_EXTENSIONS[extension];
    var filename = _extractRomName(filePath);
    RomMetadata? metadata;
    var foundSingleConsole =
        inferredConsoles?.length == 1 ? inferredConsoles!.first : null;

    // if its windows try to make a direct lookup
    if (foundSingleConsole == CONSOLE_SLUGS.windows) {
      var execName = p.basename(filePath).toLowerCase();
      var execWithParentPath =
          p.join(p.basename(p.dirname(filePath)), execName).toLowerCase();
      for (var nameVariant in [execName, execWithParentPath]) {
        var nameVariantHash = StringHelper.hashSha(nameVariant);
        try {
          var foundMetadatas = await RomsRepository()
              .fetchRomMetadata(nameVariantHash, RomMetadataLookups.EXEC_NAME);
          if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
            metadata = foundMetadatas?.first;
            break;
          }
        } catch (e) {}
      }

      if (metadata == null) {
        return RomInfo(
          slug: RomService.getRomSlug(CONSOLE_SLUGS.windows.value, filename),
          name: "unknown",
          console: CONSOLE_SLUGS.windows.value,
        );
      }
    }
    // Try a lookup by filename
    for (var console in inferredConsoles ?? [] as List<CONSOLE_SLUGS>) {
      var slug = RomService.getRomSlug(console.value, filename);
      try {
        var foundMetadatas = await RomsRepository()
            .fetchRomMetadata(slug, RomMetadataLookups.SLUG);
        if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
          metadata = foundMetadatas?.first;
          break;
        }
      } catch (e) {}
    }
    // Try to scrape by serial
    if (metadata == null) {
      try {
        var foundMetadatas = await RomsRepository()
            .fetchRomMetadata(filename, RomMetadataLookups.SERIAL);
        if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
          metadata = foundMetadatas?.firstWhereOrNull(
            (data) =>
                inferredConsoles?.any((c) => c.value == data.console) ?? false,
          );
        }
      } catch (e) {}
    }
    var fileSize = await File(filePath).length();

    // try with crc
    if (metadata == null && fileSize <= _MAX_ALLOWED_TO_READ) {
      var crc = await RomService.calculateCrc32(filePath);
      try {
        var foundMetadatas = await RomsRepository()
            .fetchRomMetadata(crc, RomMetadataLookups.CRC);
        if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
          metadata = foundMetadatas?.first;
        }
      } catch (e) {}
    }

    // try with fileSize
    if (metadata == null) {
      try {
        var foundMetadatas = await RomsRepository().fetchRomMetadata(
            fileSize.toString(), RomMetadataLookups.FILE_SIZE);
        if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
          metadata = foundMetadatas?.firstWhereOrNull((console) {
            var matchedConsole = inferredConsoles
                    ?.any((data) => data.value == console.console) ??
                false;
            var matchedName = RomService.normalizeRomTitle(console.name) ==
                RomService.normalizeRomTitle(filename);
            return matchedConsole || matchedName;
          });
        }
      } catch (e) {}
    }

    if (metadata != null) {
      if (metadata.info != null) {
        return metadata.info!;
      }
      var metadataName = StringHelper.getTitleFromFile(metadata.name);
      return RomInfo(
        slug: RomService.getRomSlug(metadata.console, metadataName),
        name: metadataName,
        console: metadata.console,
      );
    }

    return RomInfo(
      slug: RomService.getRomSlug(
          foundSingleConsole?.value ?? 'unknown', filename),
      name: filename,
      console: foundSingleConsole?.value ?? 'unknown',
    );
  }

  // Tries to scrape the information from the rom
  static Future<RomInfo?> scrapeRomInfo(RomInfo rom) async {
    RomInfo? scrapedInfo;
    try {
      var foundMetadatas = await RomsRepository()
          .fetchRomMetadata(rom.slug, RomMetadataLookups.SLUG);
      if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
        scrapedInfo = foundMetadatas?.first?.info;
      }
    } catch (e) {}
    return scrapedInfo;
  }

  /// Streams every file found inside [folderPath] recursively.
  ///
  /// This is the hot path used by the importer and intentionally avoids
  /// `listSync` so large scans don't block the UI thread or spike memory.
  static Stream<String> _scanFilesRecursively(
    String folderPath, {
    List<String>? filesToSkip,
    String? consoleFilter,
  }) async* {
    final normalizedFolderPath = folderPath.trim();
    if (normalizedFolderPath.isEmpty) {
      throw ArgumentError.value(folderPath, 'folderPath', 'Cannot be empty');
    }

    final rootDirectory = Directory(normalizedFolderPath);
    if (!await rootDirectory.exists()) {
      throw FileSystemException(
        'Folder does not exist',
        normalizedFolderPath,
      );
    }

    final skippedFiles = _normalizePathSet(filesToSkip);
    final entityStream = rootDirectory
        .list(recursive: true, followLinks: false)
        .handleError((error, stackTrace) {
      // Ignore unreadable entries and keep scanning the rest of the tree.
      print('GameImportService scan warning: $error');
    });

    await for (final entity in entityStream) {
      if (entity is! File) continue;
      final extension =
          p.extension(entity.path).replaceFirst('.', '').toLowerCase();
      final inferredConsoles = CONSOLE_EXTENSIONS[extension];
      if (inferredConsoles == null || inferredConsoles.isEmpty) {
        continue;
      }
      if (consoleFilter != null &&
          inferredConsoles
              .map((c) => c.value)
              .toSet()
              .intersection({consoleFilter}).isEmpty) {
        continue;
      }

      if ([
        ...SETUP_FILE_NAMES,
        ...REDIST_FILE_MATCHES,
        ...ENGINE_FILE_MATCHES,
      ]
          .where((match) => entity.path.toLowerCase().contains(match))
          .isNotEmpty) {
        continue;
      }

      final normalizedPath = _normalizePath(entity.path);
      if (skippedFiles.contains(normalizedPath)) continue;

      yield entity.path;
    }
  }

  static RomInfo _buildRomInfo(String filePath) {
    final extension = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    final inferredConsoles = CONSOLE_EXTENSIONS[extension];
    final inferredConsoleSlug =
        inferredConsoles != null && inferredConsoles.length == 1
            ? inferredConsoles.first.value
            : 'unknown';
    // Set the rom name to unknown for a apropiate extraction
    final romName =
        filePath.endsWith(".exe") ? "unknown" : _extractRomName(filePath);
    final slugConsole =
        inferredConsoleSlug.isEmpty ? 'unknown' : inferredConsoleSlug;

    return RomInfo(
      slug: RomService.getRomSlug(slugConsole, romName),
      name: romName,
      console: inferredConsoleSlug,
    );
  }

  static String _extractRomName(String filePath) {
    final fileName = p.basename(filePath);
    final extracted =
        StringHelper.getTitleFromFile(filePath, deleteNumerationPrefix: true)
            .trim();
    return extracted.isEmpty ? fileName : extracted;
  }

  static Set<String> _normalizePathSet(List<String>? paths) {
    if (paths == null || paths.isEmpty) return <String>{};

    return paths
        .where((path) => path.trim().isNotEmpty)
        .map(_normalizePath)
        .toSet();
  }

  static String _normalizePath(String filePath) {
    final normalized = p.normalize(filePath);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static void _notifyProgress(
    GameImportProgressCallback? onProgress, {
    required int totalFiles,
    required int processedFiles,
  }) {
    if (onProgress == null) return;

    onProgress(
      GameImportProgressPayload(
        totalFiles: totalFiles,
        processedFiles: processedFiles,
      ),
    );
  }
}

class GameImportProgressPayload {
  /// In this single-pass scan this reflects the number of eligible files
  /// discovered so far, not a precomputed final total.
  final int totalFiles;
  final int processedFiles;

  GameImportProgressPayload({
    required this.totalFiles,
    required this.processedFiles,
  });
}

class GameImportScanCallbackPayload {
  final RomInfo currentRom;
  final String currentFile;

  GameImportScanCallbackPayload({
    required this.currentRom,
    required this.currentFile,
  });
}
