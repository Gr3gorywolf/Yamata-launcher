import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:yamata_launcher/models/download_history_item.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/pages/rom_details_dialog/rom_details_dialog.dart';
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

    var hasDownloadInfo = _currentDownloadInfo != null || download != null;
    var console = ConsoleService.getConsoleFromName(romItem!.console);

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

    /// List Item View
    if (itemType == RomListItemType.listItem) {
      return RepaintBoundary(
        child: InkWell(
            onTap: () {
              navigateToDetails();
            },
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
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
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                              ),
                              if (hasDownloadInfo) ...[
                                SizedBox(
                                  height: 10,
                                ),
                                ...buildDownloadInfoContent(),
                              ],
                              ...(_currentDownloadInfo != null &&
                                      download == null
                                  ? [buildDownloadInfoProgress()]
                                  : []),
                              SizedBox(
                                height: 18,
                              ),
                              if (download == null)
                                RomActionButton(
                                  romItem,
                                  size: RomActionButtonSize.small,
                                ),
                            ],
                          ),
                          if (_currentDownloadInfo == null || download != null)
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
                                    style:
                                        Theme.of(context).textTheme.labelSmall),
                              ),
                            ),
                          if (_currentDownloadInfo == null)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: RomLibraryActions(
                                  rom: romItem, downloadHistoryItem: download),
                            )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      );
    }

    //Card View
    return RepaintBoundary(
      child: InkWell(
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
                              RomService.getLastPlayedLabel(_libraryDetails),
                              style: Theme.of(context).textTheme.labelSmall),
                        )
                    ]))),
      ),
    );
  }
}
