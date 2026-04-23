import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item/rom_list_item.dart';
import 'package:yamata_launcher/ui/widgets/view_mode_toggle.dart';

import '../../providers/app_provider.dart';

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
        const SizedBox(height: 9),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final roms = widget.roms ?? const [];
    final screenWidth = MediaQuery.of(context).size.width;
    final appProvider = Provider.of<AppProvider>(context);
    final cardWidth = appProvider.isUsingGamepad ? 280 : 283;
    final cardHeight = appProvider.isUsingGamepad ? 280 : 450;
    final gridSpacing = appProvider.isUsingGamepad ? 25 : 8;
    final gridAxisCount =
        max(1, (screenWidth / (cardWidth + gridSpacing)).floor());

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
      padding: const EdgeInsets.all(12),
      child: CustomScrollView(
        key: PageStorageKey('rom-list-${viewMode.name}'),
        cacheExtent: viewMode == ViewModeToggleMode.list ? 900 : 500,
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
                mainAxisExtent: cardHeight.toDouble(),
                mainAxisSpacing: gridSpacing.toDouble(),
                crossAxisSpacing: gridSpacing.toDouble(),
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
