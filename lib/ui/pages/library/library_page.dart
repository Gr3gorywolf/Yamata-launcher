import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/emulator.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/pages/library/library_import_dialog/library_import_dialog.dart';
import 'package:yamata_launcher/ui/widgets/console_card.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/ui/widgets/rom_list.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';
import 'package:yamata_launcher/ui/widgets/view_mode_toggle.dart';
import 'package:yamata_launcher/utils/filter_helpers.dart';
import 'package:provider/provider.dart';

enum quickFiltersTypes { none, all, installed, favorites }

var _initialToolbarValues = ToolbarValue(
    filters: [],
    search: '',
    sortBy: ToolBarSortByElement(
        label: 'Added Date',
        field: 'addedAt',
        value: ToolBarSortByType.descending));

class LibraryPage extends StatefulWidget {
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  ToolbarValue? filterValues = _initialToolbarValues;
  final toolbarKey = GlobalKey<ToolbarState>();
  quickFiltersTypes selectedQuickFilter = quickFiltersTypes.all;

  List<ToolBarFilterGroup> getFilters(List<RomLibraryItem> roms) => [
        ToolBarFilterGroup(
          groupName: 'Consoles',
          filters: roms.map((e) => e.rom.console).toSet().map((console) {
            return ToolBarFilterElement(
                label: ConsoleService.getConsoleFromName(console)?.name ?? "",
                field: 'rom.console',
                value: console);
          }).toList(),
        ),
        ToolBarFilterGroup(
          groupName: 'Availability',
          filters: [
            ToolBarFilterElement(
                label: "Installed",
                field: 'filePath',
                value: "true",
                matcher: (rom) {
                  return rom.filePath != null && rom.filePath!.isNotEmpty;
                }),
            ToolBarFilterElement(
                label: "Never Played",
                field: 'lastPlayedAt',
                value: "true",
                matcher: (rom) {
                  return rom.lastPlayedAt == null;
                }),
            ToolBarFilterElement(
                label: "Favorite", field: 'isFavorite', value: "true"),
          ],
        ),
      ];

  initState() {
    Future.microtask(() {
      var libraryProvider =
          Provider.of<LibraryProvider>(context, listen: false);
      Provider.of<DownloadSourcesProvider>(context, listen: false)
          .compileRomDownloadSources(
              libraryProvider.libraryItems.map((e) => e.rom).toList());
    }).then((value) => null);

    super.initState();
  }

  handleQuickFilterChanged(quickFiltersTypes filter) {
    switch (filter) {
      case quickFiltersTypes.all:
        toolbarKey.currentState?.setValues(ToolbarValue(
            search: filterValues?.search ?? '',
            sortBy: filterValues?.sortBy,
            filters: _initialToolbarValues.filters));
        break;
      case quickFiltersTypes.favorites:
        toolbarKey.currentState?.setValues(ToolbarValue(
            search: filterValues?.search ?? '',
            sortBy: filterValues?.sortBy,
            filters: [
              ToolBarFilterElement(
                  label: "Favorite", field: 'isFavorite', value: "true"),
            ]));
        break;
      case quickFiltersTypes.installed:
        toolbarKey.currentState?.setValues(ToolbarValue(
            search: filterValues?.search ?? '',
            sortBy: filterValues?.sortBy,
            filters: [
              ToolBarFilterElement(
                  label: "Installed",
                  field: 'filePath',
                  value: "true",
                  matcher: (rom) {
                    return rom.filePath != null && rom.filePath!.isNotEmpty;
                  }),
            ]));
        break;
      default:
        break;
    }
    setState(() {
      selectedQuickFilter = filter;
    });
  }

  handleAddToLibrary(RomInfo info, String filePath) async {
    var libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
    var item = libraryProvider.addRomToLibrary(info);
    item.filePath = filePath;
    item.addedAt = DateTime.now();
    item.isImported = true;
    await libraryProvider.updateLibraryItem(item);
  }

  @override
  Widget build(BuildContext context) {
    var libraryProvider = LibraryProvider.of(context);
    var roms = libraryProvider.libraryItems;
    var getFilteredRoms = () {
      if (filterValues == null) return roms.map((e) => e.rom).toList();
      print(selectedQuickFilter);
      return FilterHelpers.handleDynamicFilter<RomLibraryItem>(
              roms, filterValues!,
              nameField: 'rom.name')
          .map((e) => e.rom)
          .toList();
    };

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              {LibraryImportDialog.show(context, handleAddToLibrary)},
          label: Text('Import Game'),
          icon: Icon(Icons.add)),
      appBar: Toolbar(
        onChanged: (values) {
          setState(() {
            filterValues = values;
            selectedQuickFilter = quickFiltersTypes.none;
          });
        },
        key: toolbarKey,
        settings: ToolbarSettings(
          title: "Library",
          filters: getFilters(roms),
          sorts: [
            ToolBarSortByElement(
                label: 'Name',
                field: 'rom.name',
                value: ToolBarSortByType.ascending),
            ToolBarSortByElement(
                label: 'Added Date',
                field: 'addedAt',
                value: ToolBarSortByType.ascending),
            ToolBarSortByElement(
                label: 'Played time',
                field: 'playTimeMins',
                value: ToolBarSortByType.ascending),
          ],
        ),
        initialValues: filterValues,
      ),
      body: roms.isEmpty
          ? EmptyPlaceholder(
              icon: Icons.collections_bookmark,
              title: "Library is Empty",
              description:
                  "Your library is empty. Browse the catalog to find games to add to your library.",
              action: PlaceHolderAction(
                  label: "Go to catalog",
                  onPressed: () {
                    context.push('/explore');
                  }),
            )
          : RomList(
              showConsole: true,
              topRightChild: SegmentedButton<quickFiltersTypes>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: quickFiltersTypes.all,
                    icon: Icon(Icons.list, size: 18),
                  ),
                  ButtonSegment(
                    value: quickFiltersTypes.favorites,
                    icon: Icon(Icons.favorite, size: 18),
                  ),
                  ButtonSegment(
                    value: quickFiltersTypes.installed,
                    icon: Icon(Icons.download_done, size: 18),
                  ),
                ],
                selected: {selectedQuickFilter},
                onSelectionChanged: (newSelection) {
                  handleQuickFilterChanged(newSelection.first);
                },
              ),
              initialViewMode: Platform.isAndroid
                  ? ViewModeToggleMode.list
                  : ViewModeToggleMode.grid,
              roms: getFilteredRoms(),
            ),
    );
  }
}
