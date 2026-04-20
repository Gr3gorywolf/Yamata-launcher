import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/launchbox_registry.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/repository/roms_repository.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/game_import_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_preview_item.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

enum LibraryMassImportStage {
  syncingRegistry,
  setup,
  review,
}

class LibraryMassImportController extends ChangeNotifier {
  LibraryMassImportController({
    required List<Console> availableConsoles,
  }) : _availableConsoles = availableConsoles;

  static LibraryMassImportController of(
    BuildContext context, {
    bool listen = true,
  }) {
    return Provider.of<LibraryMassImportController>(
      context,
      listen: listen,
    );
  }

  final List<Console> _availableConsoles;

  bool _isDisposed = false;
  int _scrapeSession = 0;

  LibraryMassImportStage _stage = LibraryMassImportStage.syncingRegistry;
  String _scanFolder = '';
  String _selectedConsole = '';
  Map<String, LaunchboxRegistry> _launchboxRegistry = {};
  Map<String, LibraryMassImportPreviewItem> _previewItems = {};
  Set<String> _skippedResults = {};
  int _revealedItems = 0;
  bool _isInitialScrapeRunning = false;

  List<Console> get availableConsoles => _availableConsoles;
  LibraryMassImportStage get stage => _stage;
  String get scanFolder => _scanFolder;
  String get selectedConsole => _selectedConsole;
  bool get isInitialScrapeRunning => _isInitialScrapeRunning;
  int get filesFound => _revealedItems;
  Set<String> get skippedResults => _skippedResults;

  set skippedResults(Set<String> slugs) {
    if (_skippedResults == slugs) {
      return;
    }
    _skippedResults = slugs;
    _notifyListeners();
  }

  List<LibraryMassImportPreviewItem> get visibleItems {
    final list = _previewItems.values.toList();
    return list.take(_revealedItems).toList();
  }

  List<LibraryMassImportPreviewItem> get validGames => visibleItems
      .where((item) =>
          item.isValid &&
          item.matchStatus == LibraryImportPreviewStatus.COMPLETE)
      .toList();

  List<LibraryMassImportPreviewItem> get needsScrapeGames => visibleItems
      .where((item) =>
          item.isValid &&
          item.matchStatus == LibraryImportPreviewStatus.PARTIAL)
      .toList();

  List<LibraryMassImportPreviewItem> get invalidGames =>
      visibleItems.where((item) => !item.isValid).toList();

  String get selectedConsoleName {
    if (_selectedConsole.isEmpty) {
      return 'All consoles';
    }
    return ConsoleService.getConsoleFromName(_selectedConsole)?.name ??
        _selectedConsole;
  }

  bool get canCompleteImport =>
      _stage == LibraryMassImportStage.review &&
      validGames.isNotEmpty &&
      !_isInitialScrapeRunning;

  Future<void> syncRegistry() async {
    _stage = LibraryMassImportStage.syncingRegistry;
    _notifyListeners();

    final registry = await RomsRepository().fetchLaunchboxRegistry();
    final newRegistry = <String, LaunchboxRegistry>{};

    for (final entry in registry) {
      final normalizedName = RomService.normalizeRomTitle(
        StringHelper.removeMisplacedWords(entry.name),
        deleteRunes: true,
      );
      final normalizedSlug =
          RomService.getRomSlug(entry.console, normalizedName);

      if (normalizedSlug != entry.slug) {
        newRegistry[entry.slug] = entry;
      }
      newRegistry[normalizedSlug] = entry;
    }

    _launchboxRegistry = newRegistry;
    _stage = LibraryMassImportStage.setup;
    _notifyListeners();
  }

  Future<void> selectFolder() async {
    final selectedDirectory = await FileSystemService.showFolderPicker();
    if (selectedDirectory == null) {
      return;
    }

    _scanFolder = selectedDirectory;
    _notifyListeners();
  }

  void selectConsole(String? value) {
    _selectedConsole = value ?? '';
    _notifyListeners();
  }

  Future<void> startInitialScrape() async {
    final sessionId = ++_scrapeSession;

    _previewItems = {};
    _revealedItems = 0;
    _stage = LibraryMassImportStage.review;
    _isInitialScrapeRunning = true;
    _notifyListeners();

    await GameImportService.scanForGames(
      _scanFolder,
      (payload) {
        if (_shouldIgnoreSession(sessionId)) {
          return;
        }

        final isValid = payload.currentRom.name != 'unknown' &&
            payload.currentRom.console != 'unknown';

        late final LibraryMassImportPreviewItem newPreviewItem;

        if (_previewItems.containsKey(payload.currentRom.slug)) {
          final existingItem = _previewItems[payload.currentRom.slug]!;
          final sourceFiles = [...existingItem.sourceFiles, payload.currentFile]
            ..sort((a, b) => a.length.compareTo(b.length));
          final existingLibraryItem = existingItem.libraryItem;
          existingLibraryItem.filePath = sourceFiles.first;
          newPreviewItem = existingItem.copyWith(
            sourceFiles: sourceFiles,
            libraryItem: existingLibraryItem,
          );
        } else {
          var status = isValid
              ? LibraryImportPreviewStatus.PARTIAL
              : LibraryImportPreviewStatus.NONE;
          if (payload.currentRom.isScraped) {
            status = LibraryImportPreviewStatus.COMPLETE;
          }
          newPreviewItem = LibraryMassImportPreviewItem(
            sourceFiles: [payload.currentFile],
            matchStatus: status,
            isValid: isValid,
            isScraped: payload.currentRom.isScraped,
            libraryItem: RomLibraryItem(
              filePath: payload.currentFile,
              isImported: true,
              addedAt: DateTime.now(),
              rom: payload.currentRom,
            ),
          );
        }

        _previewItems[payload.currentRom.slug] = newPreviewItem;
        _notifyListeners();

        if (isValid && !payload.currentRom.isScraped) {
          unawaited(_scrapeAdditionalInfo(newPreviewItem, sessionId));
        }
      },
      onProgress: (progress) {
        if (_shouldIgnoreSession(sessionId)) {
          return;
        }

        _revealedItems = progress.totalFiles;
        _notifyListeners();
      },
      consoleFilter: _selectedConsole.isEmpty ? null : _selectedConsole,
      launchboxRegistry: _launchboxRegistry,
    );

    if (_shouldIgnoreSession(sessionId)) {
      return;
    }

    _isInitialScrapeRunning = false;
    _notifyListeners();
  }

  void backToSetup() {
    _scrapeSession++;
    _stage = LibraryMassImportStage.setup;
    _isInitialScrapeRunning = false;
    _revealedItems = 0;
    _previewItems = {};
    _notifyListeners();
  }

  void updatePreviewItem(RomLibraryItem item, String originalSlug) {
    var status = item.rom.console == 'unknown' && item.rom.name == 'unknown'
        ? LibraryImportPreviewStatus.NONE
        : LibraryImportPreviewStatus.PARTIAL;

    if (item.rom.isScraped) {
      status = LibraryImportPreviewStatus.COMPLETE;
    }

    final existingPreviewItem = _previewItems[originalSlug];
    if (existingPreviewItem == null) {
      return;
    }

    var newPreviewItems =
        Map<String, LibraryMassImportPreviewItem>.from(_previewItems);

    final existing = newPreviewItems.remove(originalSlug);
    if (existing == null) {
      return;
    }

    final entries = newPreviewItems.entries.toList();
    var index = _previewItems.keys.toList().indexOf(originalSlug);

    if (index < 0) {
      index = entries.length;
    }

    entries.insert(
      index,
      MapEntry(
        item.rom.slug,
        existing.copyWith(
          isScraped: item.rom.isScraped,
          matchStatus: status,
          libraryItem: item,
        ),
      ),
    );

    _previewItems = Map.fromEntries(entries);
    _notifyListeners();
  }

  Future<void> _scrapeAdditionalInfo(
    LibraryMassImportPreviewItem item,
    int sessionId,
  ) async {
    final updatedInfo =
        await GameImportService.scrapeRomInfo(item.libraryItem.rom);

    if (updatedInfo == null || _shouldIgnoreSession(sessionId)) {
      return;
    }

    final updatedItem = _previewItems[item.libraryItem.rom.slug];
    if (updatedItem == null) {
      return;
    }

    final libraryItem = updatedItem.libraryItem;
    libraryItem.rom = updatedInfo;

    _previewItems[item.libraryItem.rom.slug] = updatedItem.copyWith(
      libraryItem: libraryItem,
      matchStatus: LibraryImportPreviewStatus.COMPLETE,
      isValid: true,
      isScraped: true,
    );
    _notifyListeners();
  }

  bool _shouldIgnoreSession(int sessionId) {
    return _isDisposed || sessionId != _scrapeSession;
  }

  void _notifyListeners() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
