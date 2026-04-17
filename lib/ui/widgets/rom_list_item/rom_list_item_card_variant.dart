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
                        height: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Opacity(
                            opacity: 0.5,
                            child: props.gameplayThumbnail,
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
                              child: props.thumbnail,
                            ),
                          ),
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
                    subHeader: props.subHeader,
                    titleStyle: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (downloadStatus?.hasContent == true) ...[
                    const Spacer(),
                    RomListItemDownloadContent(
                      downloadStatus: downloadStatus,
                    ),
                  ],
                  if (downloadStatus?.hasProgress == true) ...[
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
                            downloadHistoryItem: props.download,
                          ),
                      ],
                    ),
                  const SizedBox(height: 3),
                  RomListItemTrailingLabel(label: props.trailingLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
