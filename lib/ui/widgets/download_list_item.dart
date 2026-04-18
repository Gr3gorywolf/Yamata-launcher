import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/download_history_item.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/pages/rom_details_dialog/rom_details_dialog.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';
import 'package:yamata_launcher/ui/widgets/rom_action_button.dart';
import 'package:yamata_launcher/ui/widgets/rom_library_actions.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_commons.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_props.dart';
import 'package:yamata_launcher/ui/widgets/rom_rating.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';
import 'package:yamata_launcher/ui/widgets/status_tag.dart';
import 'package:yamata_launcher/utils/time_helpers.dart';

class DownloadListItem extends StatelessWidget {
  final RomInfo romItem;
  final DownloadInfo? downloadInfo;
  final DownloadHistoryItem? downloadHistoryItem;
  final bool showConsole;

  const DownloadListItem({
    super.key,
    required this.romItem,
    this.downloadInfo,
    this.downloadHistoryItem,
    this.showConsole = false,
  }) : assert(
          downloadInfo != null || downloadHistoryItem != null,
          'DownloadListItem requires downloadInfo or downloadHistoryItem.',
        );
  void _openDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => RomDetailsDialog(rom: romItem),
    );
  }

  String? _buildSizeLabel() {
    final size =
        (downloadHistoryItem?.downloadSize ?? downloadInfo?.totalSize)?.trim();

    if (size == null || size.isEmpty) {
      return null;
    }

    return size;
  }

  String _buildSubHeader() {
    final console = ConsoleService.getConsoleFromName(romItem.console);
    final consoleName = _buildConsoleName(console);
    final releaseDate =
        romItem.releaseDate?.isNotEmpty == true ? romItem.releaseDate! : '---';

    if (!showConsole || consoleName == null) {
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

  RomListItemDownloadStatus? _buildDownloadStatus() {
    final contentLabel = _buildContentLabel();
    final progressValue = downloadInfo != null
        ? (downloadInfo!.downloadPercent ?? 0) / 100
        : null;

    if (contentLabel == null && progressValue == null) {
      return null;
    }

    return RomListItemDownloadStatus(
      contentLabel: contentLabel,
      statusText: downloadInfo?.downloadInfo,
      progressValue: progressValue,
    );
  }

  bool get isExtraContent {
    return downloadHistoryItem?.isExtraContent ??
        downloadInfo?.isExtraContent ??
        false;
  }

  String? _buildContentLabel() {
    if (downloadInfo == null && downloadHistoryItem == null) {
      return null;
    }

    final contentTitle =
        downloadHistoryItem?.contentTitle ?? downloadInfo?.contentTitle ?? '';

    return '$contentTitle'.trim();
  }

  String? get _trailingLabel {
    if (downloadHistoryItem == null) {
      return null;
    }

    return 'Downloaded ${TimeHelpers.getTimeAgo(downloadHistoryItem!.downloadedAt ?? DateTime.now())}';
  }

  bool get _showHistoryActions => downloadHistoryItem != null;

  @override
  Widget build(BuildContext context) {
    final downloadStatus = _buildDownloadStatus();
    var isDownloading = downloadStatus?.hasProgress == true;

    return RepaintBoundary(
      child: FocusableElement(
        focusId: romItem.slug,
        child: InkWell(
          canRequestFocus: false,
          onTap: () => _openDetails(context),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(isDownloading ? 18 : 9),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          SizedBox(
                            width: 87,
                            height: 87,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: RomThumbnail(
                                romItem,
                                timeout: const Duration(milliseconds: 60),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: RomRating(
                              rating: romItem.rating,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    StatusTag(
                                        text: isExtraContent
                                            ? 'Extra Content'
                                            : 'Base Game',
                                        type: StatusTagType.normal,
                                        size: StatusTagSize.sm),
                                    const SizedBox(width: 6),
                                    if (_buildSizeLabel() != null)
                                      StatusTag(
                                          text: _buildSizeLabel() ?? '---',
                                          type: StatusTagType.success,
                                          size: StatusTagSize.sm),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(right: 0),
                                      child: Text(
                                        romItem.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Padding(
                                  padding: EdgeInsets.only(right: 110),
                                  child: Opacity(
                                    opacity: 0.7,
                                    child: Text(
                                      _buildSubHeader(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                ),
                                if (downloadStatus?.hasContent == true) ...[
                                  SizedBox(
                                    height: 2,
                                  ),
                                  RomListItemDownloadContent(
                                    downloadStatus: downloadStatus,
                                  )
                                ],
                              ],
                            ),
                            if (_trailingLabel != null)
                              Positioned(
                                right: 0,
                                bottom: 10,
                                child: RomListItemTrailingLabel(
                                  label: _trailingLabel,
                                ),
                              ),
                            if (_showHistoryActions)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: RomLibraryActions(
                                  rom: romItem,
                                  downloadHistoryItem: downloadHistoryItem,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isDownloading) ...[
                    Container(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RomListItemDownloadProgress(
                            downloadStatus: downloadStatus,
                          ),
                          SizedBox(height: 8),
                          RomActionButton(
                            romItem,
                            size: RomActionButtonSize.small,
                          )
                        ],
                      ),
                    )
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
