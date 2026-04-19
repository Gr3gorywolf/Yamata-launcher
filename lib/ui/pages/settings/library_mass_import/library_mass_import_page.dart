import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';
import 'package:yamata_launcher/ui/widgets/searchable_dropdown_form_field.dart';

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
  List<_MassImportPreviewItem> _previewItems = const [];
  int _revealedItems = 0;
  bool _isInitialScrapeRunning = false;

  List<_MassImportPreviewItem> get _visibleItems =>
      _previewItems.take(_revealedItems).toList();

  List<_MassImportPreviewItem> get _validGames =>
      _visibleItems.where((item) => item.isValid).toList();

  List<_MassImportPreviewItem> get _invalidGames =>
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

  void _startRegistrySync() {
    _registryTimer?.cancel();
    _registryTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _stage = _LibraryMassImportStage.setup;
      });
    });
  }

  void _handleSelectFolder() {
    final folder = _selectedConsole.isEmpty
        ? r'D:\ROMs\Inbox\Mixed'
        : 'D:\\ROMs\\Inbox\\${_selectedConsole.toUpperCase()}';
    setState(() {
      _scanFolder = folder;
    });
  }

  void _handleSelectConsole(String? value) {
    setState(() {
      _selectedConsole = value ?? '';
    });
  }

  void _handleStartInitialScrape() {
    final folder = _scanFolder.isEmpty ? r'D:\ROMs\Inbox\Mixed' : _scanFolder;
    final items = _buildPreviewItems(
      selectedConsole: _selectedConsole,
      scanFolder: folder,
    );

    _scrapeTimer?.cancel();
    setState(() {
      _stage = _LibraryMassImportStage.review;
      _previewItems = items;
      _revealedItems = items.isEmpty ? 0 : 1;
      _isInitialScrapeRunning = items.isNotEmpty;
    });

    if (items.length <= 1) {
      setState(() {
        _isInitialScrapeRunning = false;
      });
      return;
    }

    _scrapeTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_revealedItems >= _previewItems.length) {
        timer.cancel();
        setState(() {
          _isInitialScrapeRunning = false;
        });
        return;
      }

      setState(() {
        _revealedItems += 1;
      });
    });
  }

  void _handleBackToSetup() {
    _scrapeTimer?.cancel();
    setState(() {
      _stage = _LibraryMassImportStage.setup;
      _isInitialScrapeRunning = false;
      _revealedItems = _previewItems.length;
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
          _LibraryMassImportStage.syncingRegistry => _buildRegistrySyncState(),
          _LibraryMassImportStage.setup => _buildSetupState(),
          _LibraryMassImportStage.review => _buildReviewState(),
        },
      ),
    );
  }

  Widget _buildRegistrySyncState() {
    final theme = Theme.of(context);

    return Center(
      key: const ValueKey('registry-sync'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Downloading the latest registry',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Preparing platform aliases, metadata lookups and scrape hints before the importer setup starts.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const _StepRow(
                    icon: Icons.download_for_offline_outlined,
                    title: 'Refreshing registry package',
                    subtitle: 'Checking for the newest platform index',
                    isActive: true,
                  ),
                  const SizedBox(height: 12),
                  const _StepRow(
                    icon: Icons.dataset_linked_outlined,
                    title: 'Updating console aliases',
                    subtitle: 'Normalizing console names for better matching',
                  ),
                  const SizedBox(height: 12),
                  const _StepRow(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Preparing importer setup',
                    subtitle: 'Loading the screen and scan defaults',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupState() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      key: const ValueKey('importer-setup'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Importer setup',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Point the importer to a folder, optionally narrow it down to a single console, and then kick off the initial scrape preview.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.75),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: FilledButton.icon(
                          onPressed: _handleSelectFolder,
                          icon: const Icon(Icons.folder_open),
                          label: Text(
                            _scanFolder.isEmpty
                                ? 'Select scan folder'
                                : 'Change scan folder',
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.folder_copy_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Folder to scan',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _scanFolder.isEmpty
                                        ? 'No folder selected yet'
                                        : _scanFolder,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'ROM console',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SearchableDropdownFormField<String>(
                        value: _selectedConsole.isNotEmpty
                            ? _selectedConsole
                            : null,
                        items: _availableConsoles
                            .map(
                              (console) => DropdownMenuItem<String>(
                                value: console.slug ?? '',
                                child: Text(console.name ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: _handleSelectConsole,
                        decoration: InputDecoration(
                          hintText: 'All consoles',
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.tips_and_updates_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Selecting a console increases scrape accuracy and helps reduce false positives during the first pass.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _scanFolder.isEmpty
                              ? null
                              : _handleStartInitialScrape,
                          icon: const Icon(Icons.travel_explore),
                          label: const Text('Start initial scrape'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final summaryTiles = [
                    _SummaryTile(
                      icon: Icons.download_done,
                      title: 'Latest registry',
                      subtitle: 'Ready for matching',
                    ),
                    _SummaryTile(
                      icon: Icons.folder_special_outlined,
                      title: 'Scan target',
                      subtitle: _scanFolder.isEmpty
                          ? 'Waiting for a folder'
                          : 'Folder selected',
                    ),
                    _SummaryTile(
                      icon: Icons.videogame_asset_outlined,
                      title: 'Console hint',
                      subtitle: _selectedConsoleName,
                    ),
                  ];

                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        for (var index = 0;
                            index < summaryTiles.length;
                            index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == summaryTiles.length - 1 ? 0 : 12,
                            ),
                            child: summaryTiles[index],
                          ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      for (var index = 0;
                          index < summaryTiles.length;
                          index++) ...[
                        Expanded(child: summaryTiles[index]),
                        if (index != summaryTiles.length - 1)
                          const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewState() {
    final theme = Theme.of(context);
    final summaryLabel = _isInitialScrapeRunning
        ? 'Initial scrape in progress'
        : 'Review matches before importing';

    return Padding(
      key: const ValueKey('review-state'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summaryLabel,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isInitialScrapeRunning
                                  ? 'Preview items are being streamed in as the importer finds candidates.'
                                  : 'Valid games can be completed immediately, while invalid games can be fixed with manual scrape.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _handleBackToSetup,
                        icon: const Icon(Icons.settings_backup_restore),
                        label: const Text('Back to setup'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_isInitialScrapeRunning)
                    LinearProgressIndicator(value: _scrapeProgress),
                  if (_isInitialScrapeRunning) const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoChip(
                        icon: Icons.check_circle_outline,
                        label: '${_validGames.length} valid games',
                      ),
                      _InfoChip(
                        icon: Icons.error_outline,
                        label: '${_invalidGames.length} invalid games',
                      ),
                      _InfoChip(
                        icon: Icons.videogame_asset,
                        label: _selectedConsoleName,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Scan folder: ${_scanFolder.isEmpty ? 'No folder selected' : _scanFolder}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.72),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Valid (${_validGames.length})'),
              Tab(text: 'Invalid (${_invalidGames.length})'),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPreviewList(
                  items: _validGames,
                  emptyTitle: 'No valid matches yet',
                  emptyDescription:
                      'As the initial scrape resolves games they will appear here ready for import.',
                ),
                _buildPreviewList(
                  items: _invalidGames,
                  emptyTitle: 'No invalid games',
                  emptyDescription:
                      'This tab will collect files that still need a better match or a manual scrape.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewList({
    required List<_MassImportPreviewItem> items,
    required String emptyTitle,
    required String emptyDescription,
  }) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 44,
                color: theme.colorScheme.onSurface.withOpacity(0.45),
              ),
              const SizedBox(height: 14),
              Text(
                emptyTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                emptyDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.72),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 110),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _MassImportPreviewCard(
          item: item,
          onManualScrape: () {
            _showPendingMessage(
              'Manual scrape for "${item.libraryItem.rom.name}" is visual-only for now.',
            );
          },
        );
      },
    );
  }

  List<_MassImportPreviewItem> _buildPreviewItems({
    required String selectedConsole,
    required String scanFolder,
  }) {
    final hasConsoleHint = selectedConsole.isNotEmpty;
    final boostedConsoleName =
        ConsoleService.getConsoleFromName(selectedConsole)?.name ??
            'Selected console';

    return [
      _MassImportPreviewItem(
        libraryItem: _buildLibraryItem(
          slug: 'chrono-trigger',
          name: 'Chrono Trigger',
          console: 'snes',
        ),
        sourceFile: '$scanFolder\\Chrono Trigger (USA).sfc',
        matchStatus: 'Auto matched',
        description:
            'Registry metadata matched successfully and this game is ready to import.',
        confidenceLabel:
            hasConsoleHint && selectedConsole == 'snes' ? 'Boosted' : 'High',
        isValid: true,
      ),
      if (hasConsoleHint)
        _MassImportPreviewItem(
          libraryItem: _buildLibraryItem(
            slug: 'hint-resolved-match',
            name: '$boostedConsoleName match candidate',
            console: selectedConsole,
          ),
          sourceFile: '$scanFolder\\mystery_dump_03.rom',
          matchStatus: 'Resolved with console hint',
          description:
              'Picking a console narrowed the candidates and resolved this previously ambiguous ROM.',
          confidenceLabel: 'Boosted',
          isValid: true,
        )
      else
        _MassImportPreviewItem(
          libraryItem: _buildLibraryItem(
            slug: 'mystery-dump-03',
            name: 'mystery_dump_03.rom',
            console: 'unknown',
          ),
          sourceFile: '$scanFolder\\mystery_dump_03.rom',
          matchStatus: 'Needs manual scrape',
          description:
              'No confident registry match yet. Selecting a console or using manual scrape would improve this result.',
          confidenceLabel: 'Low',
          isValid: false,
        ),
      _MassImportPreviewItem(
        libraryItem: _buildLibraryItem(
          slug: 'castlevania-aria-of-sorrow',
          name: 'Castlevania: Aria of Sorrow',
          console: 'gba',
        ),
        sourceFile: '$scanFolder\\Castlevania - Aria of Sorrow.gba',
        matchStatus: 'Auto matched',
        description:
            'Cover art and console metadata were found during the first scrape pass.',
        confidenceLabel:
            hasConsoleHint && selectedConsole == 'gba' ? 'Boosted' : 'High',
        isValid: true,
      ),
      _MassImportPreviewItem(
        libraryItem: _buildLibraryItem(
          slug: 'ridge-racer-type-4',
          name: 'Ridge Racer Type 4',
          console: 'psx',
        ),
        sourceFile: '$scanFolder\\Ridge Racer Type 4 (Disc 1).chd',
        matchStatus: 'Auto matched',
        description:
            'The importer found a clean title match and basic metadata for this ROM.',
        confidenceLabel:
            hasConsoleHint && selectedConsole == 'psx' ? 'Boosted' : 'Medium',
        isValid: true,
      ),
      _MassImportPreviewItem(
        libraryItem: _buildLibraryItem(
          slug: 'pokemon-stadium-rental-mix',
          name: 'Pokemon Stadium Rental Mix',
          console: hasConsoleHint ? selectedConsole : 'n64',
        ),
        sourceFile: '$scanFolder\\Pokemon Stadium Rental Mix.z64',
        matchStatus: 'Needs manual scrape',
        description:
            'The filename looks like a custom build, so the importer is holding it for manual confirmation.',
        confidenceLabel: 'Low',
        isValid: false,
      ),
      _MassImportPreviewItem(
        libraryItem: _buildLibraryItem(
          slug: 'readme-txt',
          name: 'README.txt',
          console: hasConsoleHint ? selectedConsole : 'unknown',
        ),
        sourceFile: '$scanFolder\\README.txt',
        matchStatus: 'Skipped',
        description:
            'This file does not look like a supported ROM and was categorized as invalid.',
        confidenceLabel: 'Not a ROM',
        isValid: false,
      ),
    ];
  }

  RomLibraryItem _buildLibraryItem({
    required String slug,
    required String name,
    required String console,
  }) {
    return RomLibraryItem(
      rom: RomInfo(
        slug: slug,
        name: name,
        console: console,
      ),
    );
  }
}

class _MassImportPreviewCard extends StatelessWidget {
  final _MassImportPreviewItem item;
  final VoidCallback onManualScrape;

  const _MassImportPreviewCard({
    required this.item,
    required this.onManualScrape,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor =
        item.isValid ? Colors.green.shade600 : theme.colorScheme.error;
    final consoleName =
        ConsoleService.getConsoleFromName(item.libraryItem.rom.console)?.name ??
            item.libraryItem.rom.console.toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 620;

            return Flex(
              direction: isCompact ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: isCompact
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 96,
                    height: 96,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: RomThumbnail(
                      item.libraryItem.rom,
                      height: 96,
                      width: 96,
                    ),
                  ),
                ),
                SizedBox(width: isCompact ? 0 : 16, height: isCompact ? 16 : 0),
                if (isCompact)
                  _MassImportPreviewCardContent(
                    item: item,
                    consoleName: consoleName,
                    statusColor: statusColor,
                    onManualScrape: onManualScrape,
                  )
                else
                  Expanded(
                    child: _MassImportPreviewCardContent(
                      item: item,
                      consoleName: consoleName,
                      statusColor: statusColor,
                      onManualScrape: onManualScrape,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MassImportPreviewCardContent extends StatelessWidget {
  final _MassImportPreviewItem item;
  final String consoleName;
  final Color statusColor;
  final VoidCallback onManualScrape;

  const _MassImportPreviewCardContent({
    required this.item,
    required this.consoleName,
    required this.statusColor,
    required this.onManualScrape,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              item.libraryItem.rom.name,
              style: theme.textTheme.titleMedium,
            ),
            _StatusBadge(
              color: statusColor,
              label: item.matchStatus,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.videogame_asset_outlined,
              label: consoleName,
            ),
            _InfoChip(
              icon: Icons.analytics_outlined,
              label: item.confidenceLabel,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          item.description,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          item.sourceFile,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.68),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onManualScrape,
          icon: const Icon(Icons.travel_explore),
          label: const Text('Manual scrape'),
        ),
      ],
    );
  }
}

class _MassImportPreviewItem {
  final RomLibraryItem libraryItem;
  final String sourceFile;
  final String matchStatus;
  final String description;
  final String confidenceLabel;
  final bool isValid;

  const _MassImportPreviewItem({
    required this.libraryItem,
    required this.sourceFile,
    required this.matchStatus,
    required this.description,
    required this.confidenceLabel,
    required this.isValid,
  });
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusBadge({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;

  const _StepRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withOpacity(0.7);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
