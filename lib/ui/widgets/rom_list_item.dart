import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:yamata_launcher/models/download_history_item.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/pages/rom_details_dialog/rom_details_dialog.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';
import 'package:yamata_launcher/ui/widgets/rom_action_button.dart';
import 'package:yamata_launcher/ui/widgets/rom_library_actions.dart';
import 'package:yamata_launcher/ui/widgets/rom_rating.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/utils/time_helpers.dart';

enum RomListItemType { card, listItem }

class RomListItem extends StatelessWidget {
  final RomInfo romItem;
  RomListItemType itemType;
  DownloadHistoryItem? download;
  bool showConsole;

  RomListItem(
      {required this.romItem,
      this.showConsole = false,
      this.download,
      this.itemType = RomListItemType.listItem});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final downloadSourcesProvider =
        Provider.of<DownloadSourcesProvider>(context);
    final focusId = romItem.slug;
    final _currentDownloadInfo =
        context.select<DownloadProvider, DownloadInfo?>(
      (p) => p.getDownloadInfo(romItem),
    );
    final _libraryDetails = context.select<LibraryProvider, RomLibraryItem?>(
      (p) => p.getLibraryItem(romItem.slug),
    );
    final gameplayThumbnail = RomThumbnail(
      romItem,
      customUrl: this.romItem.gameplayCovers != null &&
              romItem.gameplayCovers!.isNotEmpty
          ? romItem.gameplayCovers!.first
          : null,
      timeout: const Duration(milliseconds: 60),
    );
    final thumbnail = RomThumbnail(
      romItem,
      timeout: const Duration(milliseconds: 60),
    );
    var theme = Theme.of(context);
    var hasDownloadInfo = _currentDownloadInfo != null || download != null;
    var console = ConsoleService.getConsoleFromName(romItem!.console);

    final downloadPercent = context.select<DownloadProvider, int?>(
      (p) => p.getDownloadInfo(romItem)?.downloadPercent,
    );

    final downloadIsExtracting = context.select<DownloadProvider, bool?>(
      (p) => p.getDownloadInfo(romItem)?.isExtracting,
    );

    final loadingSource = context.select<DownloadSourcesProvider, bool?>(
        (p) => p.isRomCompilingDownloadSources(romItem.slug));

    navigateToDetails() {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => RomDetailsDialog(
                rom: romItem!,
              ));
    }

    String getSubHeader() {
      var releaseDate = (romItem?.releaseDate?.isNotEmpty ?? false
              ? romItem.releaseDate
              : "---") ??
          "";
      if (showConsole) {
        return (console?.name ?? "") + " ● " + releaseDate;
      } else {
        return releaseDate;
      }
    }

    List<Widget> buildDownloadInfoContent() {
      if (hasDownloadInfo) {
        var isExtraContent =
            download?.isExtraContent ?? _currentDownloadInfo!.isExtraContent;
        var contentTitle =
            download?.contentTitle ?? _currentDownloadInfo!.contentTitle;
        var downloadType = isExtraContent ? "Extra Content" : "Base Game";
        return [
          SizedBox(
            height: 5,
          ),
          Opacity(
            opacity: 0.7,
            child: Text(
              "(${downloadType}) ${contentTitle ?? ""}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          SizedBox(
            height: 7,
          ),
        ];
      }
      return [];
    }

    Widget buildDownloadInfoProgress() {
      return Consumer<DownloadProvider>(
        builder: (context, provider, child) {
          final downloadInfo = provider.getDownloadInfo(romItem);
          if (downloadInfo != null && download == null) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  backgroundColor: Colors.grey[800],
                  value: (downloadInfo.downloadPercent ?? 0) / 100,
                ),
                SizedBox(
                  height: 3,
                ),
                Opacity(
                  opacity: 0.7,
                  child: Text(
                    downloadInfo.downloadInfo ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                )
              ],
            );
          }
          return SizedBox.shrink();
        },
      );
    }

    Widget buildGamepadStatusInfo() {
      IconData icon;
      String text;
      Color color;

      if (downloadPercent != null) {
        icon = Icons.downloading;
        text =
            "${downloadPercent?.toStringAsFixed(0) ?? 0}% ${downloadIsExtracting == true ? "Extracted" : "Downloaded"}";
        color = theme.colorScheme.primary;
      } else if (_libraryDetails?.filePath != null &&
          _libraryDetails?.filePath != "") {
        if (_libraryDetails?.doesExists == true) {
          icon = Icons.check_circle;
          text = "Downloaded";
          color = theme.colorScheme.onSurface.withOpacity(0.7);
        } else {
          icon = Icons.error;
          text = "File not found";
          color = theme.colorScheme.error;
        }
      } else if (downloadSourcesProvider
          .getRomSources(romItem.slug)
          .isNotEmpty) {
        icon = Icons.cloud_download;
        text = "Download available";
        color = theme.colorScheme.onSurface.withOpacity(0.7);
      } else if (loadingSource == true) {
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

    /// List Item View
    if (itemType == RomListItemType.listItem) {
      final thumbnailSize = appProvider.isUsingGamepad ? 70.0 : 80.0;
      return RepaintBoundary(
        child: FocusableElement(
          focusId: focusId,
          child: InkWell(
              canRequestFocus: false,
              onTap: () {
                navigateToDetails();
              },
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(appProvider.isUsingGamepad ? 9 : 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: thumbnailSize,
                            height: thumbnailSize,
                            child: ClipRRect(
                                child: thumbnail,
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: RomRating(
                              rating: romItem!.rating,
                            ),
                          )
                        ],
                      ),
                      SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  margin: EdgeInsets.only(right: 82),
                                  child: Text(
                                    romItem!.name,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                SizedBox(
                                  height: 3,
                                ),
                                Container(
                                  margin: EdgeInsets.only(right: 110),
                                  child: Opacity(
                                    opacity: 0.7,
                                    child: Text(
                                      getSubHeader(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                ),
                                if (hasDownloadInfo) ...[
                                  SizedBox(
                                    height: appProvider.isUsingGamepad ? 0 : 10,
                                  ),
                                  ...buildDownloadInfoContent(),
                                ],
                                ...(_currentDownloadInfo != null &&
                                        download == null
                                    ? [buildDownloadInfoProgress()]
                                    : []),
                                if (appProvider.isUsingGamepad == false)
                                  SizedBox(
                                    height: 18,
                                  ),
                                if (download == null &&
                                    appProvider.isUsingGamepad == false)
                                  RomActionButton(
                                    romItem,
                                    size: RomActionButtonSize.small,
                                  ),
                              ],
                            ),
                            if (_currentDownloadInfo == null ||
                                download != null)
                              Positioned(
                                right: 0,
                                bottom: 10,
                                child: Opacity(
                                  opacity: 0.7,
                                  child: Text(
                                      download != null
                                          ? "Downloaded " +
                                              TimeHelpers.getTimeAgo(
                                                  download?.downloadedAt ??
                                                      DateTime.now())
                                          : RomService.getLastPlayedLabel(
                                              _libraryDetails),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall),
                                ),
                              ),
                            if (_currentDownloadInfo == null &&
                                appProvider.isUsingGamepad == false)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: RomLibraryActions(
                                    rom: romItem,
                                    downloadHistoryItem: download),
                              )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ),
      );
    }

    //Card View normal
    if (appProvider.isUsingGamepad == false)
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
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                height: 200,
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(6)),
                                  child: Opacity(
                                      opacity: 0.5, child: gameplayThumbnail),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                top: 0,
                                child: Center(
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    child: ClipRRect(
                                        child: thumbnail,
                                        borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: RomRating(
                                  rating: romItem!.rating,
                                  size: 12,
                                ),
                              )
                            ],
                          ),
                          SizedBox(
                            height: 7,
                          ),
                          Text(
                            romItem!.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          SizedBox(
                            height: 3,
                          ),
                          Opacity(
                            opacity: 0.7,
                            child: Text(
                              getSubHeader(),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                          if (hasDownloadInfo) ...[
                            Spacer(),
                            ...buildDownloadInfoContent(),
                          ],
                          ...(_currentDownloadInfo != null && download == null
                              ? [
                                  if (!hasDownloadInfo) Spacer(),
                                  buildDownloadInfoProgress()
                                ]
                              : []),
                          Spacer(),
                          Row(children: [
                            if (download == null)
                              RomActionButton(
                                romItem,
                                size: RomActionButtonSize.small,
                              ),
                            Spacer(),
                            if (_currentDownloadInfo == null)
                              RomLibraryActions(rom: romItem)
                          ]),
                          SizedBox(
                            height: 3,
                          ),
                          if (_currentDownloadInfo == null)
                            Opacity(
                              opacity: 0.7,
                              child: Text(
                                  RomService.getLastPlayedLabel(
                                      _libraryDetails),
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                            )
                        ]))),
          ),
        ),
      );
    // Card view for gamepad (more compact, more info on screen)
    return RepaintBoundary(
      child: FocusableElement(
        focusId: focusId,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: navigateToDetails,
          child: Builder(builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            final theme = Theme.of(context);

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
                            Text(console?.name ?? "",
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                )),
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
