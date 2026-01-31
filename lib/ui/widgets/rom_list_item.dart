import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/rom_info.dart';
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

enum RomListItemType { card, listItem }

class RomListItem extends StatelessWidget {
  final RomInfo romItem;
  RomListItemType itemType;
  bool showConsole;

  RomListItem(
      {required this.romItem,
      this.showConsole = false,
      this.itemType = RomListItemType.listItem});
  @override
  Widget build(BuildContext context) {
    var _provider = DownloadProvider.of(context);
    var libraryProvider = Provider.of<LibraryProvider>(context);
    var _downloadInfo = _provider.getDownloadInfo(romItem);
    var _libraryDetails = libraryProvider.getLibraryItem(romItem.slug);
    var gameplayThumbnail = RomThumbnail(
      this.romItem!,
      customUrl: this.romItem!.gameplayCovers != null &&
              this.romItem!.gameplayCovers!.isNotEmpty
          ? this.romItem!.gameplayCovers!.first
          : null,
      timeout: Duration(milliseconds: 60),
    );
    var thumbnail = RomThumbnail(
      this.romItem!,
      timeout: Duration(milliseconds: 60),
    );
    var console = ConsoleService.getConsoleFromName(romItem!.console);
    var isFavorite = (_libraryDetails?.isFavorite ?? false) == true;

    navigateToDetails() {
      // MaterialPageRoute route = MaterialPageRoute(
      //     builder: (context) => RomDetailsPage(rom: romItem));
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

    List<Widget> getDownloadContentInfo() {
      if (_downloadInfo != null) {
        var downloadType =
            _downloadInfo.isExtraContent ? "Extra Content" : "Base Game";
        return [
          SizedBox(
            height: 5,
          ),
          Opacity(
            opacity: 0.7,
            child: Text(
              "(${downloadType}) ${_downloadInfo.contentTitle ?? ""}",
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

    /// List Item View
    if (itemType == RomListItemType.listItem) {
      return InkWell(
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
                                style: Theme.of(context).textTheme.titleMedium,
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
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ),
                            ...(_downloadInfo != null
                                ? [
                                    SizedBox(
                                      height: 10,
                                    ),
                                    ...getDownloadContentInfo(),
                                    LinearProgressIndicator(
                                      backgroundColor: Colors.grey[800],
                                      value:
                                          (_downloadInfo.downloadPercent ?? 0) /
                                              100,
                                    ),
                                    SizedBox(
                                      height: 3,
                                    ),
                                    Opacity(
                                      opacity: 0.7,
                                      child: Text(
                                        _downloadInfo.downloadInfo ?? "",
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    )
                                  ]
                                : []),
                            SizedBox(
                              height: 18,
                            ),
                            RomActionButton(
                              romItem,
                              size: RomActionButtonSize.small,
                            ),
                          ],
                        ),
                        if (_downloadInfo == null)
                          Positioned(
                            right: 0,
                            bottom: 10,
                            child: Opacity(
                              opacity: 0.7,
                              child: Text(
                                  RomService.getLastPlayedLabel(
                                      _libraryDetails),
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                            ),
                          ),
                        if (_downloadInfo == null)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: RomLibraryActions(rom: romItem),
                          )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ));
    }

    //Card View

    return InkWell(
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
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                            child:
                                Opacity(opacity: 0.5, child: gameplayThumbnail),
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
                    ...(_downloadInfo != null
                        ? [
                            Spacer(),
                            ...getDownloadContentInfo(),
                            LinearProgressIndicator(
                              backgroundColor: Colors.grey[800],
                              value: (_downloadInfo.downloadPercent ?? 0) / 100,
                            ),
                            SizedBox(
                              height: 3,
                            ),
                            Opacity(
                              opacity: 0.7,
                              child: Text(
                                _downloadInfo.downloadInfo ?? "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            )
                          ]
                        : []),
                    Spacer(),
                    Row(children: [
                      RomActionButton(
                        romItem,
                        size: RomActionButtonSize.small,
                      ),
                      Spacer(),
                      if (_downloadInfo == null) RomLibraryActions(rom: romItem)
                    ]),
                    SizedBox(
                      height: 3,
                    ),
                    if (_downloadInfo == null)
                      Opacity(
                        opacity: 0.7,
                        child: Text(
                            RomService.getLastPlayedLabel(_libraryDetails),
                            style: Theme.of(context).textTheme.labelSmall),
                      )
                  ]))),
    );
  }
}
