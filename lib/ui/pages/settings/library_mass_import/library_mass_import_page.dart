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
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_preview_item.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_registry_sync_step.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_review_step.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_setup_step.dart';

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
  late final TabController _tabController;

  Timer? _registryTimer;
  Timer? _scrapeTimer;

  _LibraryMassImportStage _stage = _LibraryMassImportStage.syncingRegistry;
  String _scanFolder = '';
  String _selectedConsole = '';
  List<LaunchboxRegistry> _launchboxRegistry = [];
  Map<String, LibraryMassImportPreviewItem> _previewItems = {};
  int _revealedItems = 0;
  bool _isInitialScrapeRunning = false;

  List<LibraryMassImportPreviewItem> get _visibleItems =>
      _previewItems.values.take(_revealedItems).toList();

  List<LibraryMassImportPreviewItem> get _validGames =>
      _visibleItems.where((item) => item.isValid).toList();

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
    _tabController = TabController(length: 2, vsync: this);
    _startRegistrySync();
  }

  @override
  void dispose() {
    _registryTimer?.cancel();
    _scrapeTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startRegistrySync() async {
    try {
      final registry = await RomsRepository().fetchLaunchboxRegistry();
      setState(() {
        _launchboxRegistry = registry;
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
        newPreviewItem = existingItem.copyWith(
          sourceFiles: [...existingItem.sourceFiles, payload.currentFile],
        );
      } else {
        newPreviewItem = LibraryMassImportPreviewItem(
            sourceFiles: [payload.currentFile],
            matchStatus: isValid
                ? "Found name and console"
                : "Name or console not found",
            description: '',
            confidenceLabel: isValid ? "High" : "Low",
            isValid: isValid,
            isScraped: false,
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
      if (isValid) {
        handleAdditionalScrape(newPreviewItem);
      }
    }, onProgress: (progress) {
      setState(() {
        _revealedItems = progress.totalFiles;
      });
    }, consoleFilter: _selectedConsole.isEmpty ? null : _selectedConsole);

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
    var libItem = item.libraryItem;
    libItem.rom = updatedInfo;
    var newItem = item.copyWith(
      libraryItem: libItem,
      matchStatus: "Scraped",
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
              tabController: _tabController,
              isInitialScrapeRunning: _isInitialScrapeRunning,
              scrapeProgress: _scrapeProgress,
              validGames: _validGames,
              invalidGames: _invalidGames,
              selectedConsoleName: _selectedConsoleName,
              scanFolder: _scanFolder,
              onBackToSetup: _handleBackToSetup,
              onManualScrape: (item) {
                _showPendingMessage(
                  'Manual scrape for "${item.libraryItem.rom.name}" is visual-only for now.',
                );
              },
            ),
        },
      ),
    );
  }
}
