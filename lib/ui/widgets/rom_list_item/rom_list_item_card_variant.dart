import 'package:flutter/material.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';
import 'package:yamata_launcher/ui/widgets/rom_action_button.dart';
import 'package:yamata_launcher/ui/widgets/rom_library_actions.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_commons.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item_props.dart';
import 'package:yamata_launcher/ui/widgets/rom_rating.dart';

class RomListItemCardVariant extends StatelessWidget {
  final RomListItemProps props;

  const RomListItemCardVariant({
    super.key,
    required this.props,
  });

  @override
  Widget build(BuildContext context) {
    final downloadStatus = props.downloadStatus;
    var isDownloading = downloadStatus?.hasProgress == true;

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
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 260,
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
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  RomListItemHeader(
                    title: props.romItem.name,
                    titleMaxLines: isDownloading ? 1 : 2,
                    subHeader: isDownloading ? null : props.subHeader,
                    titleStyle: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (downloadStatus?.hasContent == true) ...[
                    RomListItemDownloadContent(
                      downloadStatus: downloadStatus,
                    ),
                  ],
                  if (isDownloading) ...[
                    if (downloadStatus?.hasContent != true) const Spacer(),
                    RomListItemDownloadProgress(
                      downloadStatus: downloadStatus,
                    ),
                  ],
                  const Spacer(),
                  if (props.showActionButton || props.showLibraryActions)
                    Row(
                      children: [
                        if (props.showActionButton)
                          RomActionButton(
                            props.romItem,
                            size: RomActionButtonSize.small,
                          ),
                        const Spacer(),
                        if (props.showLibraryActions)
                          RomLibraryActions(
                            rom: props.romItem,
                          ),
                      ],
                    ),
                  if (!isDownloading) ...[
                    const SizedBox(height: 3),
                    RomListItemTrailingLabel(label: props.trailingLabel),
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
