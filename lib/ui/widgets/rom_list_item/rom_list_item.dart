import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/download_history_item.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
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
import 'package:yamata_launcher/utils/time_helpers.dart';

enum RomListItemType { card, listItem }

class RomListItem extends StatelessWidget {
  final RomInfo romItem;
  final RomListItemType itemType;
  final DownloadHistoryItem? download;
  final bool showConsole;

  const RomListItem({
    super.key,
    required this.romItem,
    this.showConsole = false,
    this.download,
    this.itemType = RomListItemType.listItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUsingGamepad =
        context.select<AppProvider, bool>((p) => p.isUsingGamepad);
    final currentDownloadInfo = context.select<DownloadProvider, DownloadInfo?>(
      (p) => p.getDownloadInfo(romItem),
    );
    final libraryDetails = context.select<LibraryProvider, RomLibraryItem?>(
      (p) => p.getLibraryItem(romItem.slug),
    );
    final hasAvailableSources = context.select<DownloadSourcesProvider, bool>(
      (p) => p.getRomSources(romItem.slug).isNotEmpty,
    );
    final isLoadingSources = context.select<DownloadSourcesProvider, bool>(
      (p) => p.isRomCompilingDownloadSources(romItem.slug),
    );
    final console = ConsoleService.getConsoleFromName(romItem.console);
    final status = _buildStatus(
      theme: theme,
      currentDownloadInfo: currentDownloadInfo,
      libraryDetails: libraryDetails,
      hasAvailableSources: hasAvailableSources,
      isLoadingSources: isLoadingSources,
    );
    final props = RomListItemProps(
      romItem: romItem,
      download: download,
      libraryDetails: libraryDetails,
      thumbnail: RomThumbnail(
        romItem,
        timeout: const Duration(milliseconds: 60),
      ),
      gameplayThumbnail: RomThumbnail(
        romItem,
        customUrl: romItem.gameplayCovers?.isNotEmpty == true
            ? romItem.gameplayCovers!.first
            : null,
        timeout: const Duration(milliseconds: 60),
      ),
      focusId: romItem.slug,
      subHeader: _buildSubHeader(console),
      consoleName: showConsole ? _buildConsoleName(console) : null,
      downloadStatus: _buildDownloadStatus(currentDownloadInfo),
      trailingLabel: _buildTrailingLabel(
        currentDownloadInfo: currentDownloadInfo,
        libraryDetails: libraryDetails,
      ),
      isUsingGamepad: isUsingGamepad,
      showActionButton: download == null && !isUsingGamepad,
      showLibraryActions: currentDownloadInfo == null && !isUsingGamepad,
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

  String? _buildDownloadContentLabel(DownloadInfo? currentDownloadInfo) {
    final source = download ?? currentDownloadInfo;
    if (source == null) {
      return null;
    }

    final isExtraContent = download?.isExtraContent ??
        currentDownloadInfo?.isExtraContent ??
        false;
    final contentTitle =
        download?.contentTitle ?? currentDownloadInfo?.contentTitle ?? '';
    final contentType = isExtraContent ? 'Extra Content' : 'Base Game';

    return '($contentType) $contentTitle'.trim();
  }

  RomListItemDownloadStatus? _buildDownloadStatus(
    DownloadInfo? currentDownloadInfo,
  ) {
    final contentLabel = _buildDownloadContentLabel(currentDownloadInfo);
    final progressValue = currentDownloadInfo != null && download == null
        ? (currentDownloadInfo.downloadPercent ?? 0) / 100
        : null;

    if (contentLabel == null && progressValue == null) {
      return null;
    }

    return RomListItemDownloadStatus(
      contentLabel: contentLabel,
      statusText: currentDownloadInfo?.downloadInfo,
      progressValue: progressValue,
    );
  }

  String? _buildTrailingLabel({
    required DownloadInfo? currentDownloadInfo,
    required RomLibraryItem? libraryDetails,
  }) {
    if (download != null) {
      return 'Downloaded ${TimeHelpers.getTimeAgo(download!.downloadedAt ?? DateTime.now())}';
    }

    if (currentDownloadInfo != null) {
      return null;
    }

    return RomService.getLastPlayedLabel(libraryDetails);
  }

  RomListItemStatus _buildStatus({
    required ThemeData theme,
    required DownloadInfo? currentDownloadInfo,
    required RomLibraryItem? libraryDetails,
    required bool hasAvailableSources,
    required bool isLoadingSources,
  }) {
    if (currentDownloadInfo != null) {
      final percent = currentDownloadInfo.downloadPercent ?? 0;
      return RomListItemStatus(
        icon: Icons.downloading,
        text:
            '$percent% ${currentDownloadInfo.isExtracting ? 'Extracted' : 'Downloaded'}',
        color: theme.colorScheme.primary,
      );
    }

    if (libraryDetails?.filePath?.isNotEmpty == true) {
      if (libraryDetails?.doesExists == true) {
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
