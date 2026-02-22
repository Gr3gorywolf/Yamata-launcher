import 'dart:io';
import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/ui/pages/rom_details_dialog/rom_details_dialog.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';
import 'package:yamata_launcher/ui/widgets/rom_action_button.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';
import 'package:yamata_launcher/ui/widgets/view_mode_toggle.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/services/files_system_service.dart';

class RomList extends StatefulWidget {
  final bool isLoading;
  final List<RomInfo>? roms;
  final bool showConsole;
  final ViewModeToggleMode? initialViewMode;
  final Function(ViewModeToggleMode)? onViewModeChanged;
  final Widget? topRightChild;

  const RomList({
    super.key,
    this.isLoading = false,
    this.roms,
    this.showConsole = false,
    this.initialViewMode,
    this.onViewModeChanged,
    this.topRightChild,
  });

  @override
  State<RomList> createState() => _RomListState();
}

class _RomListState extends State<RomList> with AutomaticKeepAliveClientMixin {
  late ViewModeToggleMode viewMode;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
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
                setState(() => viewMode = value);
                widget.onViewModeChanged?.call(value);
              },
            ),
            const Spacer(),
            if (widget.topRightChild != null) widget.topRightChild!,
          ],
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final roms = widget.roms ?? const [];
    final screenWidth = MediaQuery.of(context).size.width;
    final gridAxisCount = max(1, (screenWidth / 283).floor());

    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (roms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _buildTop(),
            const Expanded(
              child: EmptyPlaceholder(
                icon: Icons.search_off,
                title: "No ROMs Found",
                description: "No ROMs found matching the current criteria.",
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildTop()),
          if (viewMode == ViewModeToggleMode.list)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final rom = roms[index];

                  return RepaintBoundary(
                    child: _RomListItemWrapper(
                        rom: rom, showConsole: widget.showConsole),
                  );
                },
                childCount: roms.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                addSemanticIndexes: false,
              ),
            ),
          if (viewMode == ViewModeToggleMode.grid)
            SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final rom = roms[index];
                  return RepaintBoundary(
                    child: RomListItem(
                      romItem: rom,
                      showConsole: widget.showConsole,
                      itemType: RomListItemType.card,
                    ),
                  );
                },
                childCount: roms.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                addSemanticIndexes: false,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridAxisCount,
                mainAxisExtent: 410,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
            ),
        ],
      ),
    );
  }
}

class _RomListItemWrapper extends StatelessWidget {
  final RomInfo rom;
  final bool showConsole;

  const _RomListItemWrapper({
    required this.rom,
    required this.showConsole,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RomListItem(
        romItem: rom,
        showConsole: showConsole,
        itemType: RomListItemType.listItem,
      ),
    );
  }
}
