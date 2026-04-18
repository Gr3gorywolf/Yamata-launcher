import 'package:flutter/material.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';
import 'package:yamata_launcher/ui/widgets/rom_action_button.dart';
import 'package:yamata_launcher/ui/widgets/rom_library_actions.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_commons.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_props.dart';
import 'package:yamata_launcher/ui/widgets/rom_rating.dart';

class RomListItemListVariant extends StatelessWidget {
  final RomListItemProps props;

  const RomListItemListVariant({
    super.key,
    required this.props,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailSize = props.isUsingGamepad ? 70.0 : 80.0;
    final downloadStatus = props.downloadStatus;

    return RepaintBoundary(
      child: FocusableElement(
        focusId: props.focusId,
        child: InkWell(
          canRequestFocus: false,
          onTap: props.onOpenDetails,
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(props.isUsingGamepad ? 9 : 13),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          SizedBox(
                            width: thumbnailSize,
                            height: thumbnailSize,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: props.thumbnail,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: RomRating(
                              rating: props.romItem.rating,
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
                                RomListItemHeader(
                                  title: props.romItem.name,
                                  subHeader: props.subHeader,
                                  titleStyle:
                                      Theme.of(context).textTheme.titleMedium,
                                  titleMaxLines: 1,
                                  titleRightInset: 82,
                                  subHeaderRightInset: 110,
                                ),
                                // Gamepad content
                                if (props.isUsingGamepad) ...[
                                  const SizedBox(height: 6),
                                  RomListItemStatusInfo(status: props.status),
                                ],
                                if (props.showActionButton) ...[
                                  SizedBox(
                                    height: 5,
                                  ),
                                  RomActionButton(
                                    props.romItem,
                                    size: RomActionButtonSize.small,
                                  ),
                                ]
                              ],
                            ),
                            if (props.hasTrailingLabel)
                              Positioned(
                                right: 0,
                                bottom: 10,
                                child: RomListItemTrailingLabel(
                                  label: props.trailingLabel,
                                ),
                              ),
                            if (props.showLibraryActions)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: RomLibraryActions(
                                  rom: props.romItem,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!props.isUsingGamepad && downloadStatus != null) ...[
                    if (downloadStatus?.hasContent == true) ...[
                      SizedBox(
                        height: 4,
                      ),
                      RomListItemDownloadContent(
                        downloadStatus: downloadStatus,
                      ),
                    ],
                    RomListItemDownloadProgress(
                      downloadStatus: downloadStatus,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
