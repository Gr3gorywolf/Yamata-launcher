import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/launchbox_registry.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/repository/roms_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/game_import_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_preview_item.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_registry_sync_step.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_review_step.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_setup_step.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

enum _LibraryMassImportStage {
  syncingRegistry,
  setup,
  review,
}

class LibraryMassImportPage extends StatefulWidget {
  const LibraryMassImportPage({super.key});

  @override
  State<LibraryMassImportPage> createState() => _LibraryMassImportPageState();
}

class _LibraryMassImportPageState extends State<LibraryMassImportPage>
    with SingleTickerProviderStateMixin {
  late final List<Console> _availableConsoles;

  Timer? _registryTimer;
  Timer? _scrapeTimer;

  _LibraryMassImportStage _stage = _LibraryMassImportStage.syncingRegistry;
  String _scanFolder = '';
  String _selectedConsole = '';
  Map<String, LaunchboxRegistry> _launchboxRegistry = {};
  Map<String, LibraryMassImportPreviewItem> _previewItems = {};
  int _revealedItems = 0;
  bool _isInitialScrapeRunning = false;

  List<LibraryMassImportPreviewItem> get _visibleItems =>
      _previewItems.values.take(_revealedItems).toList();

  List<LibraryMassImportPreviewItem> get _validGames => _visibleItems
      .where((item) =>
          item.isValid &&
          item.matchStatus == LibraryImportPreviewStatus.COMPLETE)
      .toList();

  List<LibraryMassImportPreviewItem> get _needsScrape => _visibleItems
      .where((item) =>
          item.isValid &&
          item.matchStatus == LibraryImportPreviewStatus.PARTIAL)
      .toList();

  List<LibraryMassImportPreviewItem> get _invalidGames =>
      _visibleItems.where((item) => !item.isValid).toList();

  double get _scrapeProgress {
    if (_previewItems.isEmpty) return 0;
    return _revealedItems / _previewItems.length;
  }

  String get _selectedConsoleName {
    if (_selectedConsole.isEmpty) return 'All consoles';
    return ConsoleService.getConsoleFromName(_selectedConsole)?.name ??
        _selectedConsole;
  }

  @override
  void initState() {
    super.initState();
    _availableConsoles = ConsoleService.getConsoles(includeUnsupported: true);
    _startRegistrySync();
  }

  @override
  void dispose() {
    _registryTimer?.cancel();
    _scrapeTimer?.cancel();
    super.dispose();
  }

  void _startRegistrySync() async {
    try {
      final registry = await RomsRepository().fetchLaunchboxRegistry();
      var newRegistry = <String, LaunchboxRegistry>{};
      for (var entry in registry) {
        var normalizedName = RomService.normalizeRomTitle(
            StringHelper.removeMisplacedWords(entry.name),
            deleteRunes: true);
        var normalizedSlug =
            RomService.getRomSlug(entry.console, normalizedName);

        if (normalizedSlug != entry.slug) {
          newRegistry[entry.slug] = entry;
        }
        newRegistry[normalizedSlug] = entry;
      }
      setState(() {
        _launchboxRegistry = newRegistry;
        _stage = _LibraryMassImportStage.setup;
      });
    } catch (er) {
      print('Error fetching launchbox registry: $er');
      AlertsService.showAlert(navigatorContext!, 'Error',
          'Failed to fetch launchbox registry. ${er.toString()}',
          cancelable: false,
          acceptTitle: 'Retry',
          callback: _startRegistrySync, onClose: () {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    }
  }

  void _handleSelectFolder() async {
    final selectedDirectory = await FileSystemService.showFolderPicker();

    if (selectedDirectory == null) return;
    setState(() {
      _scanFolder = selectedDirectory;
    });
  }

  void _handleSelectConsole(String? value) {
    setState(() {
      _selectedConsole = value ?? '';
    });
  }

  void _handleStartInitialScrape() async {
    _scrapeTimer?.cancel();
    setState(() {
      _stage = _LibraryMassImportStage.review;
      _isInitialScrapeRunning = true;
    });

    await GameImportService.scanForGames(_scanFolder, (payload) {
      var isValid = payload.currentRom.name != 'unknown' &&
          payload.currentRom.console != 'unknown';
      var newPreviewItem = null;
      if (_previewItems.containsKey(payload.currentRom.slug)) {
        var existingItem = _previewItems[payload.currentRom.slug]!;
        var sourceFiles = [...existingItem.sourceFiles, payload.currentFile];
        sourceFiles.sort((a, b) => a.length.compareTo(b.length));
        var existingLibraryItem = existingItem.libraryItem;
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
                rom: payload.currentRom));
      }

      _previewItems[payload.currentRom.slug] = newPreviewItem;
      setState(() {
        _previewItems;
      });
      if (isValid && !payload.currentRom.isScraped) {
        handleAdditionalScrape(newPreviewItem);
      }
    }, onProgress: (progress) {
      setState(() {
        _revealedItems = progress.totalFiles;
      });
    },
        consoleFilter: _selectedConsole.isEmpty ? null : _selectedConsole,
        launchboxRegistry: _launchboxRegistry);

    setState(() {
      _isInitialScrapeRunning = false;
    });
  }

  void handleAdditionalScrape(LibraryMassImportPreviewItem item) async {
    var updatedInfo =
        await GameImportService.scrapeRomInfo(item.libraryItem.rom);
    if (updatedInfo == null) {
      return;
    }
    var updatedItem = _previewItems[item.libraryItem.rom.slug];
    if (updatedItem == null) return;
    var libItem = updatedItem.libraryItem;
    libItem.rom = updatedInfo;
    var newItem = updatedItem.copyWith(
      libraryItem: libItem,
      matchStatus: LibraryImportPreviewStatus.COMPLETE,
      confidenceLabel: "High",
      isValid: true,
      isScraped: true,
    );
    _previewItems[item.libraryItem.rom.slug] = newItem;
    setState(() {
      _previewItems;
    });
  }

  void _handleBackToSetup() {
    _scrapeTimer?.cancel();
    setState(() {
      _stage = _LibraryMassImportStage.setup;
      _isInitialScrapeRunning = false;
      _revealedItems = 0;
      _previewItems = {};
    });
  }

  void _showPendingMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleUpdate(RomLibraryItem item) {
    var status = item.rom.console == 'unknown' && item.rom.name == 'unknown'
        ? LibraryImportPreviewStatus.NONE
        : LibraryImportPreviewStatus.PARTIAL;
    if (item.rom.isScraped) {
      status = LibraryImportPreviewStatus.COMPLETE;
    }
    var existingPreviewItem = _previewItems[item.rom.slug];
    if (existingPreviewItem == null) return;
    _previewItems[item.rom.slug] = existingPreviewItem.copyWith(
        isScraped: item.rom.isScraped, matchStatus: status, libraryItem: item);
    setState(() {
      _previewItems;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canCompleteImport = _stage == _LibraryMassImportStage.review &&
        _validGames.isNotEmpty &&
        !_isInitialScrapeRunning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Mass Import'),
      ),
      floatingActionButton: _stage == _LibraryMassImportStage.review
          ? FloatingActionButton.extended(
              onPressed: canCompleteImport
                  ? () {
                      _showPendingMessage(
                        'Complete import is visual-only for now.',
                      );
                    }
                  : null,
              icon: const Icon(Icons.done_all),
              label: const Text('Complete import'),
            )
          : null,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (_stage) {
          _LibraryMassImportStage.syncingRegistry =>
            const LibraryMassImportRegistrySyncStep(
              key: ValueKey('registry-sync'),
            ),
          _LibraryMassImportStage.setup => LibraryMassImportSetupStep(
              key: const ValueKey('importer-setup'),
              availableConsoles: _availableConsoles,
              scanFolder: _scanFolder,
              selectedConsole: _selectedConsole,
              selectedConsoleName: _selectedConsoleName,
              onSelectFolder: _handleSelectFolder,
              onSelectConsole: _handleSelectConsole,
              onStartInitialScrape: _handleStartInitialScrape,
            ),
          _LibraryMassImportStage.review => LibraryMassImportReviewStep(
              key: const ValueKey('review-state'),
              isInitialScrapeRunning: _isInitialScrapeRunning,
              scrapeProgress: _scrapeProgress,
              validGames: _validGames,
              invalidGames: _invalidGames,
              needsScrapeGames: _needsScrape,
              filesFound: _revealedItems,
              selectedConsoleName: _selectedConsoleName,
              scanFolder: _scanFolder,
              onBackToSetup: _handleBackToSetup,
              onUpdate: _handleUpdate,
            ),
        },
      ),
    );
  }
}
