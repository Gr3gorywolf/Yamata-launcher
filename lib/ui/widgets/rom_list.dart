import 'dart:io';
import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/ui/pages/rom_details_dialog/rom_details_dialog.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/ui/widgets/rom_action_button.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';
import 'package:yamata_launcher/ui/widgets/view_mode_toggle.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/services/files_system_service.dart';

class RomList extends StatefulWidget {
  bool? isLoading = false;
  List<RomInfo>? roms;
  bool showConsole;
  ViewModeToggleMode? initialViewMode;
  Function(ViewModeToggleMode)? onViewModeChanged;
  Widget? topRightChild;
  RomList(
      {this.isLoading,
      this.roms,
      this.showConsole = false,
      this.initialViewMode,
      this.onViewModeChanged,
      this.topRightChild});

  @override
  State<RomList> createState() => _RomListState();
}

class _RomListState extends State<RomList> {
  var viewMode = ViewModeToggleMode.list;
  @override
  void initState() {
    viewMode = widget.initialViewMode ?? ViewModeToggleMode.grid;
  }

  Widget _buildTop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ViewModeToggle(
              value: viewMode,
              onChanged: (value) {
                if (mounted) setState(() => viewMode = value);
                if (widget.onViewModeChanged != null) {
                  widget.onViewModeChanged!(value);
                }
              },
            ),
            Spacer(),
            if (widget.topRightChild != null) widget.topRightChild!,
          ],
        ),
        SizedBox(
          height: 5,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var gridAxisCount =
        max(1, (MediaQuery.of(context).size.width / 275).floor());
    if (widget.isLoading == true) {
      return const Center(child: CircularProgressIndicator());
    }
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: widget.roms?.isEmpty ?? true
          ? Column(
              children: [
                _buildTop(),
                Expanded(
                  child: EmptyPlaceholder(
                      icon: Icons.search_off,
                      title: "No ROMs Found",
                      description:
                          "No ROMs found matching the current criteria."),
                ),
              ],
            )
          : FadeIn(
              duration: Duration(seconds: 1),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildTop(),
                  ),
                  if (viewMode == ViewModeToggleMode.list)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final rom = widget.roms![index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: RomListItem(
                              romItem: rom,
                              showConsole: widget.showConsole,
                              itemType: RomListItemType.listItem,
                            ),
                          );
                        },
                        childCount: widget.roms!.length,
                      ),
                    ),
                  if (viewMode == ViewModeToggleMode.grid)
                    SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final rom = widget.roms![index];
                            return RomListItem(
                                romItem: rom,
                                showConsole: widget.showConsole,
                                itemType: RomListItemType.card);
                          },
                          childCount: widget.roms!.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridAxisCount,
                          mainAxisExtent: 410,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        )),
                ],
              ),
            ),
    );
  }
}
