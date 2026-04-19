import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/pages/library/library_import_dialog/library_import_dialog.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_preview_item.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';
import 'package:yamata_launcher/ui/widgets/status_tag.dart';

class LibraryMassImportPreviewCard extends StatelessWidget {
  final LibraryMassImportPreviewItem item;
  final Function(RomLibraryItem) onUpdate;

  const LibraryMassImportPreviewCard({
    super.key,
    required this.item,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              direction: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                SizedBox(width: 16),
                _LibraryMassImportPreviewCardContent(
                  item: item,
                  consoleName: consoleName,
                  onUpdate: onUpdate,
                )
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LibraryMassImportPreviewItemStatus {
  final LibraryMassImportPreviewItem item;
  _LibraryMassImportPreviewItemStatus(this.item);
  String get label {
    switch (item.matchStatus) {
      case LibraryImportPreviewStatus.COMPLETE:
        return "Matched and scraped";
      case LibraryImportPreviewStatus.PARTIAL:
        return "Needs scraping";
      case LibraryImportPreviewStatus.NONE:
        return "Invalid match";
    }
  }

  String get confidenceLabel {
    switch (item.matchStatus) {
      case LibraryImportPreviewStatus.COMPLETE:
        return "High";
      case LibraryImportPreviewStatus.PARTIAL:
        return "Medium";
      case LibraryImportPreviewStatus.NONE:
        return "Low";
    }
  }
}

class _LibraryMassImportPreviewCardContent extends StatelessWidget {
  final LibraryMassImportPreviewItem item;
  final String consoleName;
  final Function(RomLibraryItem) onUpdate;

  _LibraryMassImportPreviewCardContent({
    required this.item,
    required this.consoleName,
    required this.onUpdate,
  });

  late final _LibraryMassImportPreviewItemStatus dataByConfidence =
      _LibraryMassImportPreviewItemStatus(item);
  StatusTagType get statusColor {
    switch (item.matchStatus) {
      case LibraryImportPreviewStatus.COMPLETE:
        return StatusTagType.success;
      case LibraryImportPreviewStatus.PARTIAL:
        return StatusTagType.warning;
      case LibraryImportPreviewStatus.NONE:
        return StatusTagType.error;
    }
  }

  void selectItemSourceFile(String source) {
    final updatedLibraryItem = item.libraryItem;
    updatedLibraryItem.filePath = source;
    onUpdate(updatedLibraryItem);
  }

  void handleUpdate(BuildContext context) async {
    var dialog = await LibraryImportDialog.show(context, (info, path) {
      final updatedItem = item.libraryItem;
      updatedItem.rom = info;
      updatedItem.filePath = path;
      onUpdate(updatedItem);
    }, libraryItem: item.libraryItem, canEditConsole: false);
  }

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
            StatusTag(
              size: StatusTagSize.sm,
              text: dataByConfidence.label,
              type: statusColor,
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LibraryMassImportCardInfoChip(
              icon: Icons.videogame_asset_outlined,
              label: consoleName,
            ),
            const SizedBox(width: 12),
            _LibraryMassImportCardInfoChip(
              icon: Icons.analytics_outlined,
              label: dataByConfidence.confidenceLabel,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...item.sourceFiles.map(
          (source) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: item.sourceFiles.length > 1
                  ? () => selectItemSourceFile(source)
                  : null,
              child: Row(
                children: [
                  if (item.sourceFiles.length > 1) ...[
                    Icon(
                        item.libraryItem.filePath == source
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 16),
                    const SizedBox(width: 6),
                  ],
                  Wrap(
                    children: [
                      Text(
                        source,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.68),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => handleUpdate(context),
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
