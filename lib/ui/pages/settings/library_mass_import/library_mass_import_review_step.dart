import 'package:flutter/material.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_controller.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_preview_card.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_preview_item.dart';

class LibraryMassImportReviewStep extends StatelessWidget {
  const LibraryMassImportReviewStep({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = LibraryMassImportController.of(context);
    final isInitialScrapeRunning = controller.isInitialScrapeRunning;
    final filesFound = controller.filesFound;
    final validGames = controller.validGames;
    final needsScrapeGames = controller.needsScrapeGames;
    final invalidGames = controller.invalidGames;
    final selectedConsoleName = controller.selectedConsoleName;
    final scanFolder = controller.scanFolder;
    final validFilesCount = validGames.fold<int>(
      0,
      (count, validGame) => count + validGame.sourceFiles.length,
    );
    final invalidFilesCount = invalidGames.fold<int>(
      0,
      (count, invalidGame) => count + invalidGame.sourceFiles.length,
    );
    final summaryLabel = isInitialScrapeRunning
        ? 'Scanning in progress...'
        : 'Review matches before completing import';

    double getScrapeProgressPercent() {
      final total =
          validGames.length + needsScrapeGames.length + invalidGames.length;

      if (total == 0 || filesFound == 0) {
        return 0.0;
      }

      return (total / filesFound).clamp(0.0, 1.0);
    }

    int getSkippedCount() {
      var skippeableGames = [...needsScrapeGames, ...validGames]
          .map((game) => game.libraryItem.rom.slug)
          .toSet();
      final skippedCount = controller.skippedResults
          .toList()
          .where((result) => skippeableGames.contains(result))
          .length;
      return skippedCount;
    }

    final tabs = [
      _LibraryMassImportTabData(
        id: 'valid',
        title: 'Valid (${validGames.length})',
        items: validGames,
        emptyTitle: 'No valid matches yet',
        emptyDescription:
            'As the initial scrape resolves games they will appear here ready for import.',
      ),
      _LibraryMassImportTabData(
        id: 'needs-scrape',
        title: 'Needs Scrape (${needsScrapeGames.length})',
        items: needsScrapeGames,
        emptyTitle: 'No games need scraping',
        emptyDescription:
            'This tab will collect games that still need a manual scrape.',
      ),
      _LibraryMassImportTabData(
        id: 'invalid',
        title: 'Invalid (${invalidGames.length})',
        items: invalidGames,
        emptyTitle: 'No invalid games',
        emptyDescription:
            'This tab will collect files that still need a better match or a manual scrape.',
      ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          final tabBar = TabBar(
            tabs: tabs.map((tab) => Tab(text: tab.title)).toList(),
          );

          return AnimatedBuilder(
            animation: tabController,
            builder: (context, _) {
              final activeTab = tabs[tabController.index];

              return CustomScrollView(
                key: PageStorageKey(
                  'library-mass-import-review-${activeTab.id}',
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                    sliver: SliverToBoxAdapter(
                      child: Card(
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
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: controller.backToSetup,
                                    icon: const Icon(Icons.settings),
                                    label: const Text('Back to setup'),
                                  ),
                                ],
                              ),
                              if (isInitialScrapeRunning)
                                LinearProgressIndicator(
                                  value: getScrapeProgressPercent(),
                                ),
                              if (isInitialScrapeRunning)
                                const SizedBox(height: 14),
                              Wrap(
                                spacing: 0,
                                runSpacing: 0,
                                children: [
                                  _LibraryMassImportReviewChip(
                                    icon: Icons.search,
                                    label: '$filesFound Found',
                                  ),
                                  _LibraryMassImportReviewChip(
                                    icon: Icons.check_circle_outline,
                                    label: '$validFilesCount Valid',
                                  ),
                                  _LibraryMassImportReviewChip(
                                    icon: Icons.sync,
                                    label:
                                        '${needsScrapeGames.length} Incomplete',
                                  ),
                                  _LibraryMassImportReviewChip(
                                    icon: Icons.error_outline,
                                    label: '$invalidFilesCount Invalid',
                                  ),
                                  _LibraryMassImportReviewChip(
                                    icon: Icons.redo,
                                    label: "${getSkippedCount()} Skipped",
                                  ),
                                  _LibraryMassImportReviewChip(
                                    icon: Icons.videogame_asset,
                                    label: selectedConsoleName,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Scan folder: ${scanFolder.isEmpty ? 'No folder selected' : scanFolder}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.72),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _LibraryMassImportStickyTabBarDelegate(
                      backgroundColor: theme.scaffoldBackgroundColor,
                      tabBar: tabBar,
                    ),
                  ),
                  _LibraryMassImportPreviewSliverList(
                    storageKey: activeTab.id,
                    items: activeTab.items,
                    emptyTitle: activeTab.emptyTitle,
                    emptyDescription: activeTab.emptyDescription,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _LibraryMassImportTabData {
  final String id;
  final String title;
  final List<LibraryMassImportPreviewItem> items;
  final String emptyTitle;
  final String emptyDescription;

  const _LibraryMassImportTabData({
    required this.id,
    required this.title,
    required this.items,
    required this.emptyTitle,
    required this.emptyDescription,
  });
}

class _LibraryMassImportPreviewSliverList extends StatelessWidget {
  final String storageKey;
  final List<LibraryMassImportPreviewItem> items;
  final String emptyTitle;
  final String emptyDescription;

  const _LibraryMassImportPreviewSliverList({
    required this.storageKey,
    required this.items,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 18, 32, 110),
          child: Center(
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
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
      sliver: SliverList(
        key: PageStorageKey('library-mass-import-$storageKey'),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index.isOdd) {
              return const SizedBox(height: 12);
            }

            final item = items[index ~/ 2];
            final originalSlug = item.libraryItem.rom.slug;

            return LibraryMassImportPreviewCard(
              key: ValueKey(originalSlug),
              item: item,
            );
          },
          childCount: items.length * 2 - 1,
        ),
      ),
    );
  }
}

class _LibraryMassImportStickyTabBarDelegate
    extends SliverPersistentHeaderDelegate {
  final Color backgroundColor;
  final TabBar tabBar;

  const _LibraryMassImportStickyTabBarDelegate({
    required this.backgroundColor,
    required this.tabBar,
  });

  @override
  double get minExtent => tabBar.preferredSize.height + 10;

  @override
  double get maxExtent => tabBar.preferredSize.height + 10;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: tabBar,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_LibraryMassImportStickyTabBarDelegate oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.tabBar != tabBar;
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
