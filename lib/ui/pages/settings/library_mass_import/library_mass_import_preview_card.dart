import 'package:flutter/material.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_preview_item.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';

class LibraryMassImportPreviewCard extends StatelessWidget {
  final LibraryMassImportPreviewItem item;
  final VoidCallback onManualScrape;

  const LibraryMassImportPreviewCard({
    super.key,
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
                  _LibraryMassImportPreviewCardContent(
                    item: item,
                    consoleName: consoleName,
                    statusColor: statusColor,
                    onManualScrape: onManualScrape,
                  )
                else
                  Expanded(
                    child: _LibraryMassImportPreviewCardContent(
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

class _LibraryMassImportPreviewCardContent extends StatelessWidget {
  final LibraryMassImportPreviewItem item;
  final String consoleName;
  final Color statusColor;
  final VoidCallback onManualScrape;

  const _LibraryMassImportPreviewCardContent({
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
            _LibraryMassImportStatusBadge(
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
            _LibraryMassImportCardInfoChip(
              icon: Icons.videogame_asset_outlined,
              label: consoleName,
            ),
            _LibraryMassImportCardInfoChip(
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

class _LibraryMassImportCardInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LibraryMassImportCardInfoChip({
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

class _LibraryMassImportStatusBadge extends StatelessWidget {
  final Color color;
  final String label;

  const _LibraryMassImportStatusBadge({
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
