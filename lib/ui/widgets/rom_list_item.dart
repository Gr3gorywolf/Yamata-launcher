import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/models/download_history_item.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/pages/rom_details_dialog/rom_details_dialog.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';
import 'package:yamata_launcher/ui/widgets/rom_action_button.dart';
import 'package:yamata_launcher/ui/widgets/rom_library_actions.dart';
import 'package:yamata_launcher/ui/widgets/rom_rating.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';
import 'package:yamata_launcher/utils/time_helpers.dart';

enum RomListItemType { card, listItem }

class RomListItem extends StatelessWidget {
  final RomInfo romItem;
  RomListItemType itemType;
  DownloadHistoryItem? download;
  bool showConsole;

  RomListItem({
    required this.romItem,
    this.showConsole = false,
    this.download,
    this.itemType = RomListItemType.listItem,
  });

  @override
  Widget build(BuildContext context) {
    final isUsingGamepad =
        context.select<AppProvider, bool>((p) => p.isUsingGamepad);
    final focusId = romItem.slug;
    final downloadState = context.select<
        DownloadProvider,
        ({
          bool hasInfo,
          int? percent,
          bool isExtracting,
          String? infoLabel,
          bool isExtraContent,
          String? contentTitle,
        })>(
      (p) {
        final info = p.getDownloadInfo(romItem);
        return (
          hasInfo: info != null,
          percent: info?.downloadPercent,
          isExtracting: info?.isExtracting == true,
          infoLabel: info?.downloadInfo,
          isExtraContent: info?.isExtraContent == true,
          contentTitle: info?.contentTitle,
        );
      },
    );
    final libraryState = context.select<
        LibraryProvider,
        ({
          String? filePath,
          bool fileExists,
          String lastPlayedLabel,
        })>(
      (p) {
        final item = p.getLibraryItem(romItem.slug);
        return (
          filePath: item?.filePath,
          fileExists: item?.doesExists == true,
          lastPlayedLabel: RomService.getLastPlayedLabel(item),
        );
      },
    );
    final hasDownloadSources = context.select<DownloadSourcesProvider, bool>(
      (p) => p.getRomSources(romItem.slug).isNotEmpty,
    );
    final loadingSource = context.select<DownloadSourcesProvider, bool>(
      (p) => p.isRomCompilingDownloadSources(romItem.slug),
    );

    final gameplayThumbnail = RomThumbnail(
      romItem,
      customUrl:
          romItem.gameplayCovers != null && romItem.gameplayCovers!.isNotEmpty
              ? romItem.gameplayCovers!.first
              : null,
      timeout: const Duration(milliseconds: 60),
    );
    final thumbnail = RomThumbnail(
      romItem,
      timeout: const Duration(milliseconds: 60),
    );
    final theme = Theme.of(context);
    final hasDownloadInfo = downloadState.hasInfo || download != null;
    final console = ConsoleService.getConsoleFromName(romItem.console);
    final hasLibraryFile = libraryState.filePath?.isNotEmpty == true;

    void navigateToDetails() {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => RomDetailsDialog(
                rom: romItem,
              ));
    }

    String getSubHeader() {
      final releaseDate = (romItem.releaseDate?.isNotEmpty ?? false)
          ? romItem.releaseDate!
          : "---";
      if (showConsole) {
        return "${console?.name ?? ""} - $releaseDate";
      }
      return releaseDate;
    }

    List<Widget> buildDownloadInfoContent() {
      if (!hasDownloadInfo) {
        return [];
      }

      final isExtraContent =
          download?.isExtraContent ?? downloadState.isExtraContent;
      final contentTitle = download?.contentTitle ?? downloadState.contentTitle;
      final downloadType = isExtraContent ? "Extra Content" : "Base Game";

      return [
        const SizedBox(height: 5),
        Opacity(
          opacity: 0.7,
          child: Text(
            "($downloadType) ${contentTitle ?? ""}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ),
        const SizedBox(height: 7),
      ];
    }

    Widget buildDownloadInfoProgress() {
      if (!downloadState.hasInfo || download != null) {
        return const SizedBox.shrink();
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            backgroundColor: Colors.grey[800],
            value: (downloadState.percent ?? 0) / 100,
          ),
          const SizedBox(height: 3),
          Opacity(
            opacity: 0.7,
            child: Text(
              downloadState.infoLabel ?? "",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          )
        ],
      );
    }

    Widget buildGamepadStatusInfo() {
      IconData icon;
      String text;
      Color color;

      if (downloadState.percent != null) {
        icon = Icons.downloading;
        text =
            "${downloadState.percent}% ${downloadState.isExtracting ? "Extracting" : "Downloaded"}";
        color = theme.colorScheme.primary;
      } else if (hasLibraryFile) {
        if (libraryState.fileExists) {
          icon = Icons.check_circle;
          text = "Downloaded";
          color = theme.colorScheme.onSurface.withOpacity(0.7);
        } else {
          icon = Icons.error;
          text = "File not found";
          color = theme.colorScheme.error;
        }
      } else if (hasDownloadSources) {
        icon = Icons.cloud_download;
        text = "Download available";
        color = theme.colorScheme.onSurface.withOpacity(0.7);
      } else if (loadingSource) {
        icon = Icons.hourglass_top;
        text = "Checking sources...";
        color = theme.colorScheme.onSurface.withOpacity(0.7);
      } else {
        icon = Icons.file_download_off;
        text = "Not Available";
        color = theme.colorScheme.onSurface.withOpacity(0.7);
      }

      return Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (itemType == RomListItemType.listItem) {
      final thumbnailSize = isUsingGamepad ? 70.0 : 80.0;
      final rowHeight = isUsingGamepad ? 96.0 : 124.0;

      return RepaintBoundary(
        child: FocusableElement(
          focusId: focusId,
          child: InkWell(
            canRequestFocus: false,
            onTap: navigateToDetails,
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(isUsingGamepad ? 9 : 13),
                child: SizedBox(
                  height: rowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          SizedBox(
                            width: thumbnailSize,
                            height: thumbnailSize,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: thumbnail,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: RomRating(rating: romItem.rating),
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
                                Container(
                                  margin: const EdgeInsets.only(right: 82),
                                  child: Text(
                                    romItem.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  margin: const EdgeInsets.only(right: 110),
                                  child: Opacity(
                                    opacity: 0.7,
                                    child: Text(
                                      getSubHeader(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ),
                                ),
                                if (isUsingGamepad && download == null) ...[
                                  const SizedBox(height: 7),
                                  buildGamepadStatusInfo(),
                                ],
                                if (hasDownloadInfo) ...[
                                  SizedBox(height: isUsingGamepad ? 0 : 10),
                                  ...buildDownloadInfoContent(),
                                ],
                                if (downloadState.hasInfo && download == null)
                                  buildDownloadInfoProgress(),
                                if (!isUsingGamepad) const SizedBox(height: 18),
                                if (download == null && !isUsingGamepad)
                                  RomActionButton(
                                    romItem,
                                    size: RomActionButtonSize.small,
                                  ),
                              ],
                            ),
                            if (!downloadState.hasInfo || download != null)
                              Positioned(
                                right: 0,
                                bottom: 10,
                                child: Opacity(
                                  opacity: 0.7,
                                  child: Text(
                                    download != null
                                        ? "Downloaded ${TimeHelpers.getTimeAgo(download?.downloadedAt ?? DateTime.now())}"
                                        : libraryState.lastPlayedLabel,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                              ),
                            if (!downloadState.hasInfo && !isUsingGamepad)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: RomLibraryActions(
                                  rom: romItem,
                                  downloadHistoryItem: download,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!isUsingGamepad) {
      return RepaintBoundary(
        child: FocusableElement(
          focusId: focusId,
          child: InkWell(
            canRequestFocus: false,
            onTap: navigateToDetails,
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 200,
                          child: ClipRRect(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(6)),
                            child: Opacity(
                              opacity: 0.5,
                              child: gameplayThumbnail,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: thumbnail,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: RomRating(
                            rating: romItem.rating,
                            size: 12,
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      romItem.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Opacity(
                      opacity: 0.7,
                      child: Text(
                        getSubHeader(),
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    if (hasDownloadInfo) ...[
                      const Spacer(),
                      ...buildDownloadInfoContent(),
                    ],
                    if (downloadState.hasInfo && download == null) ...[
                      if (!hasDownloadInfo) const Spacer(),
                      buildDownloadInfoProgress(),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        if (download == null)
                          RomActionButton(
                            romItem,
                            size: RomActionButtonSize.small,
                          ),
                        const Spacer(),
                        if (!downloadState.hasInfo)
                          RomLibraryActions(rom: romItem),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (!downloadState.hasInfo)
                      Opacity(
                        opacity: 0.7,
                        child: Text(
                          libraryState.lastPlayedLabel,
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: FocusableElement(
        focusId: focusId,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: navigateToDetails,
          child: Builder(builder: (context) {
            final isFocused = Focus.of(context).hasFocus;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        )
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 180,
                      child: thumbnail,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 130,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.75),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            romItem.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (showConsole)
                            Text(
                              console?.name ?? "",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          const SizedBox(height: 4),
                          buildGamepadStatusInfo(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
