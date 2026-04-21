import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/launchbox_registry.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_metadata.dart';
import 'package:yamata_launcher/repository/game_metadata_repository.dart';
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
  static const int _completeRomInfoBatchSize = 100;
  static Map<String, List<RomMetadata>>? _fullMetadataCache;
  static Map<String, List<RomMetadata>>? _sizeCache;
  static Map<String, List<RomMetadata>>? _serialCache;
  static Map<String, List<RomMetadata>>? _execCache;

  /// Performs a single-pass recursive scan over the selected folder.
  ///
  /// The scan uses a filesystem stream instead of materializing the full tree,
  /// which keeps memory usage low even on very large folders.
  static Future<void> scanForGames(
    String folderPath,
    GameImportScanCallback callback, {
    List<String>? filesToSkip,
    GameImportProgressCallback? onProgress,
    Map<String, LaunchboxRegistry>? launchboxRegistry,
    String? consoleFilter,
  }) async {
    var discoveredFiles = 0;
    var processedFiles = 0;
    final pendingLookups = <_PendingRomLookup>[];
    var batchQueue = Future<void>.value();
    _notifyProgress(
      onProgress,
      totalFiles: discoveredFiles,
      processedFiles: processedFiles,
      isPreparing: true,
    );
    await _loadMetadataCache();
    _notifyProgress(
      onProgress,
      totalFiles: discoveredFiles,
      processedFiles: processedFiles,
      isPreparing: false,
    );
    await for (final filePath in _scanFilesRecursively(
      folderPath,
      filesToSkip: filesToSkip,
      consoleFilter: consoleFilter,
    )) {
      discoveredFiles += 1;
      final rom = _buildRomInfo(filePath);
      if (rom.console == 'unknown' || rom.name == "unknown") {
        pendingLookups.add(
          _PendingRomLookup(
            filePath: filePath,
            fallbackRom: rom,
          ),
        );
        if (pendingLookups.length >= _completeRomInfoBatchSize) {
          final currentBatch = List<_PendingRomLookup>.from(pendingLookups);
          pendingLookups.clear();
          batchQueue = batchQueue.then((_) async {
            await _flushPendingLookups(
              currentBatch,
              launchboxRegistry: launchboxRegistry,
              onResolved: (payload) {
                callback(payload);
                processedFiles += 1;
                _notifyProgress(
                  onProgress,
                  totalFiles: discoveredFiles,
                  processedFiles: processedFiles,
                );
              },
            );
          });
        }
        continue;
      }

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
    }

    if (pendingLookups.isNotEmpty) {
      final currentBatch = List<_PendingRomLookup>.from(pendingLookups);
      pendingLookups.clear();
      batchQueue = batchQueue.then((_) async {
        await _flushPendingLookups(
          currentBatch,
          launchboxRegistry: launchboxRegistry,
          onResolved: (payload) {
            callback(payload);
            processedFiles += 1;
            _notifyProgress(
              onProgress,
              totalFiles: discoveredFiles,
              processedFiles: processedFiles,
            );
          },
        );
      });
    }

    await batchQueue;
    await _clearMetadataCache();
  }

  static Future<void> _flushPendingLookups(
      List<_PendingRomLookup> pendingLookups,
      {required void Function(GameImportScanCallbackPayload payload) onResolved,
      Map<String, LaunchboxRegistry>? launchboxRegistry,
      String? consoleFilter}) async {
    final resolvedPayloads = await Future.wait(
      pendingLookups.map((lookup) async {
        try {
          final rom = await _completeRomInfo(lookup.filePath,
              launchboxRegistry: launchboxRegistry,
              consoleFilter: consoleFilter);
          return GameImportScanCallbackPayload(
            currentRom: rom,
            currentFile: lookup.filePath,
          );
        } catch (e) {
          print(
            'GameImportService lookup warning for ${lookup.filePath}: $e',
          );
          return GameImportScanCallbackPayload(
            currentRom: lookup.fallbackRom,
            currentFile: lookup.filePath,
          );
        }
      }),
    );

    for (final payload in resolvedPayloads) {
      onResolved(payload);
    }
  }

  static Future<void> _loadMetadataCache() async {
    try {
      _fullMetadataCache =
          await GameMetadataRepository.retrieveMetadataIndexByType(
              RomMetadataLookups.SLUG);
      _sizeCache = await GameMetadataRepository.retrieveMetadataIndexByType(
          RomMetadataLookups.FILE_SIZE);
      _serialCache = await GameMetadataRepository.retrieveMetadataIndexByType(
          RomMetadataLookups.SERIAL);
      _execCache = await GameMetadataRepository.retrieveMetadataIndexByType(
          RomMetadataLookups.EXEC_NAME);
    } on Exception catch (e, st) {
      print("Error loading metadata cache: $e $st");
      return;
    }
  }

  static Future<void> _clearMetadataCache() async {
    _fullMetadataCache = null;
    _sizeCache = null;
    _serialCache = null;
    _execCache = null;
  }

  /// Tries to complete the rom info with multiple strategies, starting with the less expensive ones (filename-based) and going up to more expensive ones (crc-based).
  static Future<RomInfo> _completeRomInfo(String filePath,
      {Map<String, LaunchboxRegistry>? launchboxRegistry,
      String? consoleFilter}) async {
    final extension = p.extension(filePath).replaceFirst('.', '').toLowerCase();
    var inferredConsoles = CONSOLE_EXTENSIONS[extension];
    if (consoleFilter != null && inferredConsoles != null) {
      inferredConsoles =
          inferredConsoles.where((c) => c.value == consoleFilter).toList();
    }
    var filename = _extractRomName(filePath);
    RomMetadata? metadata;
    var foundSingleConsole =
        inferredConsoles?.length == 1 ? inferredConsoles!.first : null;

    // if its windows try to make a direct lookup
    if (foundSingleConsole == CONSOLE_SLUGS.windows) {
      var execName = p.basename(filePath).toLowerCase();
      var execWithParentPath =
          p.join(p.basename(p.dirname(filePath)), execName).toLowerCase();
      for (var nameVariant in [
        execWithParentPath,
        execName,
      ]) {
        var foundMetadatas = _execCache?[nameVariant];
        if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
          metadata = foundMetadatas?.first;
          break;
        }
      }

      if (metadata == null) {
        return RomInfo(
          slug: RomService.getRomSlug(CONSOLE_SLUGS.windows.value, filename),
          name: "unknown",
          console: CONSOLE_SLUGS.windows.value,
        );
      }
    }
    // Try to scrape directly the rom
    for (var console in inferredConsoles ?? [] as List<CONSOLE_SLUGS>) {
      var slug = RomService.getRomSlug(console.value, filename);
      RomInfo? scrapedInfo = await scrapeRomInfo(
          RomInfo(slug: slug, name: filename, console: console.value),
          launchboxRegistry: launchboxRegistry);

      if (scrapedInfo != null) {
        return scrapedInfo;
      }
    }
    // Try to scrape by serial
    if (metadata == null) {
      var foundMetadatas = _serialCache?[filename.toLowerCase()];
      if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
        metadata = foundMetadatas?.firstWhereOrNull(
          (data) =>
              inferredConsoles?.any((c) => c.value == data.console) ?? false,
        );
      }
    }
    var fileSize = await File(filePath).length();

    // try with crc wont
    // if (metadata == null && fileSize <= _MAX_ALLOWED_TO_READ) {
    //   var crc = await RomService.calculateCrc32(filePath);
    //   try {
    //     var foundMetadatas = await RomsRepository()
    //         .fetchRomMetadata(crc, RomMetadataLookups.CRC);
    //     if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
    //       metadata = foundMetadatas?.first;
    //     }
    //   } catch (e) {}
    // }

    // try with fileSize
    if (metadata == null) {
      var foundMetadatas = _sizeCache?[fileSize.toString()];
      if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
        metadata = foundMetadatas?.firstWhereOrNull((dat) {
          var matchedConsole = inferredConsoles
              ?.firstWhereOrNull((data) => data.value == dat.console);
          var datSlug = RomService.getRomSlug(dat.console, dat.name,
              removeMisplacedWords: true);
          var fileSlug = RomService.getRomSlug(
              matchedConsole?.value ?? '', filename,
              removeMisplacedWords: true);
          return datSlug == fileSlug;
        });
      }
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
  static Future<RomInfo?> scrapeRomInfo(RomInfo rom,
      {Map<String, LaunchboxRegistry>? launchboxRegistry}) async {
    RomInfo? scrapedInfo;
    if (launchboxRegistry != null && !launchboxRegistry.containsKey(rom.slug)) {
      var normalizedSlug = RomService.getRomSlug(rom.console, rom.name,
          removeMisplacedWords: true);
      if (!launchboxRegistry.containsKey(normalizedSlug)) {
        return null;
      }
      rom.slug = launchboxRegistry[normalizedSlug]!.slug;
    }
    try {
      var foundMetadatas = _fullMetadataCache != null
          ? _fullMetadataCache![rom.slug]
          : await RomsRepository()
              .fetchRomMetadata(rom.slug, RomMetadataLookups.SLUG);
      if (foundMetadatas != null && foundMetadatas.isNotEmpty) {
        scrapedInfo = foundMetadatas?.first?.info;
      }
    } catch (e) {
      print("Error scraping rom info for ${rom.name} (${rom.console}): $e");
    }
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
    bool isPreparing = false,
  }) {
    if (onProgress == null) return;

    onProgress(
      GameImportProgressPayload(
        totalFiles: totalFiles,
        processedFiles: processedFiles,
        isPreparing: isPreparing,
      ),
    );
  }
}

class GameImportProgressPayload {
  /// In this single-pass scan this reflects the number of eligible files
  /// discovered so far, not a precomputed final total.
  final int totalFiles;
  final int processedFiles;
  final bool isPreparing;

  GameImportProgressPayload({
    required this.totalFiles,
    required this.processedFiles,
    this.isPreparing = false,
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

class _PendingRomLookup {
  final String filePath;
  final RomInfo fallbackRom;

  _PendingRomLookup({
    required this.filePath,
    required this.fallbackRom,
  });
}
