import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/pages/rom_details_dialog/rom_details_dialog.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_card_gamepad_variant.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_card_variant.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_list_variant.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_props.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';

enum RomListItemType { card, listItem }

class RomListItem extends StatelessWidget {
  final RomInfo romItem;
  final RomListItemType itemType;
  final bool showConsole;

  const RomListItem({
    super.key,
    required this.romItem,
    this.showConsole = false,
    this.itemType = RomListItemType.listItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUsingGamepad =
        context.select<AppProvider, bool>((p) => p.isUsingGamepad);
    final downloadState =
        context.select<DownloadProvider, RomListItemDownloadState>(
      (p) => RomListItemDownloadState.fromDownloadInfo(
        p.getDownloadInfo(romItem),
      ),
    );
    final libraryState =
        context.select<LibraryProvider, RomListItemLibraryState>(
      (p) {
        final libraryItem = p.getLibraryItem(romItem.slug);
        return RomListItemLibraryState.fromLibraryItem(
          libraryItem: libraryItem,
          lastPlayedLabel: RomService.getLastPlayedLabel(libraryItem),
        );
      },
    );
    final hasAvailableSources = context.select<DownloadSourcesProvider, bool>(
      (p) => p.getRomSources(romItem.slug).isNotEmpty,
    );
    final isLoadingSources = context.select<DownloadSourcesProvider, bool>(
      (p) => p.isRomCompilingDownloadSources(romItem.slug),
    );

    final isPlaying = context.select<LibraryProvider, bool>(
      (p) => p.isGameRunning(romItem.slug),
    );

    final console = ConsoleService.getConsoleFromName(romItem.console);
    final status = _buildStatus(
      theme: theme,
      downloadState: downloadState,
      libraryState: libraryState,
      hasAvailableSources: hasAvailableSources,
      isLoadingSources: isLoadingSources,
      isPlaying: isPlaying,
    );
    final props = RomListItemProps(
      romItem: romItem,
      thumbnail: RomThumbnail(
        romItem,
        timeout: const Duration(milliseconds: 60),
      ),
      focusId: romItem.slug,
      subHeader: _buildSubHeader(console),
      consoleName: showConsole ? _buildConsoleName(console) : null,
      downloadStatus: _buildDownloadStatus(downloadState),
      trailingLabel: _buildTrailingLabel(
        downloadState: downloadState,
        libraryState: libraryState,
      ),
      isUsingGamepad: isUsingGamepad,
      showActionButton: !isUsingGamepad,
      showLibraryActions: !downloadState.hasCurrentDownload && !isUsingGamepad,
      status: status,
      onOpenDetails: () => _openDetails(context),
    );

    if (itemType == RomListItemType.listItem) {
      return RomListItemListVariant(props: props);
    }

    if (!isUsingGamepad) {
      return RomListItemCardVariant(props: props);
    }

    return RomListItemCardGamepadVariant(props: props);
  }

  void _openDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => RomDetailsDialog(rom: romItem),
    );
  }

  String _buildSubHeader(Console? console) {
    final releaseDate =
        romItem.releaseDate?.isNotEmpty == true ? romItem.releaseDate! : '---';

    if (!showConsole) {
      return releaseDate;
    }

    final consoleName = _buildConsoleName(console);

    if (consoleName == null) {
      return releaseDate;
    }

    return '$consoleName - $releaseDate';
  }

  String? _buildConsoleName(Console? console) {
    if (!showConsole) {
      return null;
    }

    final name = console?.name?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }

    return name;
  }

  String? _buildDownloadContentLabel(RomListItemDownloadState downloadState) {
    if (!downloadState.hasCurrentDownload) {
      return null;
    }

    final isExtraContent = downloadState.isExtraContent;
    final contentTitle = downloadState.contentTitle ?? '';
    final contentType = isExtraContent ? 'Extra Content' : 'Base Game';

    return '($contentType) $contentTitle'.trim();
  }

  RomListItemDownloadStatus? _buildDownloadStatus(
    RomListItemDownloadState downloadState,
  ) {
    final contentLabel = _buildDownloadContentLabel(downloadState);
    final progressValue = downloadState.hasCurrentDownload
        ? (downloadState.progressPercent ?? 0) / 100
        : null;

    if (contentLabel == null && progressValue == null) {
      return null;
    }

    return RomListItemDownloadStatus(
      contentLabel: contentLabel,
      statusText: downloadState.statusText,
      progressValue: progressValue,
      isPaused: downloadState.isPaused,
    );
  }

  String? _buildTrailingLabel({
    required RomListItemDownloadState downloadState,
    required RomListItemLibraryState libraryState,
  }) {
    if (downloadState.hasCurrentDownload) {
      return null;
    }

    return libraryState.lastPlayedLabel;
  }

  RomListItemStatus _buildStatus({
    required ThemeData theme,
    required RomListItemDownloadState downloadState,
    required RomListItemLibraryState libraryState,
    required bool hasAvailableSources,
    required bool isLoadingSources,
    bool isPlaying = false,
  }) {
    if (isPlaying) {
      return RomListItemStatus(
        icon: Icons.play_arrow,
        text: 'Running...',
        color: theme.colorScheme.primary,
      );
    }
    if (downloadState.hasCurrentDownload) {
      final percent = downloadState.progressPercent ?? 0;
      if (downloadState.isPaused) {
        return RomListItemStatus(
          icon: Icons.pause,
          text: 'Paused - $percent%',
          color: Colors.yellow.withOpacity(0.7),
        );
      }
      return RomListItemStatus(
        icon: Icons.downloading,
        text:
            '$percent% ${downloadState.isExtracting ? 'Extracted' : 'Downloaded'}',
        color: theme.colorScheme.primary,
      );
    }

    if (libraryState.filePath?.isNotEmpty == true) {
      if (libraryState.fileExists == true) {
        return RomListItemStatus(
          icon: Icons.check_circle,
          text: 'Downloaded',
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        );
      }

      return RomListItemStatus(
        icon: Icons.error,
        text: 'File not found',
        color: theme.colorScheme.error,
      );
    }

    if (hasAvailableSources) {
      return RomListItemStatus(
        icon: Icons.cloud_download,
        text: 'Download available',
        color: theme.colorScheme.onSurface.withOpacity(0.7),
      );
    }

    if (isLoadingSources) {
      return RomListItemStatus(
        icon: Icons.hourglass_top,
        text: 'Checking sources...',
        color: theme.colorScheme.onSurface.withOpacity(0.7),
      );
    }

    return RomListItemStatus(
      icon: Icons.file_download_off,
      text: 'Not Available',
      color: theme.colorScheme.onSurface.withOpacity(0.7),
    );
  }
}
