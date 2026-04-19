import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_preview_card.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_preview_item.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item.dart';

class LibraryMassImportReviewStep extends StatelessWidget {
  final bool isInitialScrapeRunning;
  final double scrapeProgress;
  final int filesFound;
  final List<LibraryMassImportPreviewItem> validGames;
  final List<LibraryMassImportPreviewItem> needsScrapeGames;
  final List<LibraryMassImportPreviewItem> invalidGames;
  final String selectedConsoleName;
  final String scanFolder;
  final VoidCallback onBackToSetup;
  final Function(RomLibraryItem, String) onUpdate;

  LibraryMassImportReviewStep({
    super.key,
    required this.isInitialScrapeRunning,
    required this.scrapeProgress,
    required this.validGames,
    required this.filesFound,
    required this.needsScrapeGames,
    required this.invalidGames,
    required this.selectedConsoleName,
    required this.scanFolder,
    required this.onBackToSetup,
    required this.onUpdate,
  });
  int get validFilesCount {
    var count = 0;
    for (var validGame in validGames) {
      count += validGame.sourceFiles.length;
    }
    return count;
  }

  int get invalidFilesCount {
    var count = 0;
    for (var invalidGame in invalidGames) {
      count += invalidGame.sourceFiles.length;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryLabel = isInitialScrapeRunning
        ? 'Initial scrape in progress'
        : 'Review matches before importing';

    return Padding(
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
                        child: Text(
                          summaryLabel,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onBackToSetup,
                        icon: const Icon(Icons.settings),
                        label: const Text('Back to setup'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  if (isInitialScrapeRunning)
                    LinearProgressIndicator(value: scrapeProgress),
                  if (isInitialScrapeRunning) const SizedBox(height: 14),
                  Wrap(
                    spacing: 0,
                    runSpacing: 0,
                    children: [
                      _LibraryMassImportReviewChip(
                        icon: Icons.search,
                        label: '${filesFound} files found',
                      ),
                      _LibraryMassImportReviewChip(
                        icon: Icons.check_circle_outline,
                        label: '${validFilesCount} valid game files',
                      ),
                      _LibraryMassImportReviewChip(
                        icon: Icons.error_outline,
                        label: '${invalidFilesCount} invalid game files',
                      ),
                      _LibraryMassImportReviewChip(
                        icon: Icons.sync,
                        label: '${needsScrapeGames.length}  needs scraping',
                      ),
                      _LibraryMassImportReviewChip(
                        icon: Icons.videogame_asset,
                        label: selectedConsoleName,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Scan folder: ${scanFolder.isEmpty ? 'No folder selected' : scanFolder}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.72),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          DefaultTabController(
              length: 3,
              child: Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: 'Valid (${validGames.length})'),
                          Tab(
                              text:
                                  'Needs Scrape (${needsScrapeGames.length})'),
                          Tab(text: 'Invalid (${invalidGames.length})'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _LibraryMassImportPreviewList(
                              items: validGames,
                              emptyTitle: 'No valid matches yet',
                              emptyDescription:
                                  'As the initial scrape resolves games they will appear here ready for import.',
                              onUpdate: onUpdate,
                            ),
                            _LibraryMassImportPreviewList(
                              items: needsScrapeGames,
                              emptyTitle: 'No games need scraping',
                              emptyDescription:
                                  'This tab will collect games that still need a manual scrape.',
                              onUpdate: onUpdate,
                            ),
                            _LibraryMassImportPreviewList(
                              items: invalidGames,
                              emptyTitle: 'No invalid games',
                              emptyDescription:
                                  'This tab will collect files that still need a better match or a manual scrape.',
                              onUpdate: onUpdate,
                            ),
                          ],
                        ),
                      ),
                    ]),
              )),
        ],
      ),
    );
  }
}

class _LibraryMassImportPreviewList extends StatelessWidget {
  final List<LibraryMassImportPreviewItem> items;
  final String emptyTitle;
  final String emptyDescription;
  final Function(RomLibraryItem, String) onUpdate;

  const _LibraryMassImportPreviewList({
    required this.items,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
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
        final originalSlug = item.libraryItem.rom.slug;
        return LibraryMassImportPreviewCard(
          key: ValueKey(originalSlug),
          item: item,
          onUpdate: (updatedItem) => onUpdate(updatedItem, originalSlug),
        );
      },
    );
  }
}

class _LibraryMassImportReviewChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LibraryMassImportReviewChip({
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
