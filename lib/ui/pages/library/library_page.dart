import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/pages/library/library_import_dialog/library_import_dialog.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/ui/widgets/rom_list.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:yamata_launcher/utils/toolbar_settings/filters/library_item_filters.dart';
import 'package:yamata_launcher/utils/toolbar_settings/sorts/library_item_sorts.dart';

Map<String, dynamic> _buildLibraryFilterPayload(
  List<RomLibraryItem> roms,
  ToolbarValue<RomLibraryItem>? toolbarValue,
) {
  return {
    'roms': roms
        .asMap()
        .entries
        .map((entry) => {
              'index': entry.key,
              'slug': entry.value.rom.slug,
              'console': entry.value.rom.console,
              'name': entry.value.rom.name,
              'normalizedName': entry.value.rom.name.normalizeForSearch(),
              'isFavorite': entry.value.isFavorite,
              'playTimeMins': entry.value.playTimeMins,
              'filePath': entry.value.filePath ?? '',
              'addedAtMs': entry.value.addedAt?.millisecondsSinceEpoch,
              'lastPlayedAtMs':
                  entry.value.lastPlayedAt?.millisecondsSinceEpoch,
            })
        .toList(growable: false),
    'search': toolbarValue?.search ?? '',
    'filters': (toolbarValue?.filters ?? const [])
        .map((filter) => {
              'field': filter.field,
              'value': filter.value,
            })
        .toList(growable: false),
    'sortField': toolbarValue?.sortBy?.field,
    'sortDirection': toolbarValue?.sortBy?.value.name,
  };
}

List<int> _filterLibraryPayload(Map<String, dynamic> payload) {
  final roms = (payload['roms'] as List).cast<Map>();
  final searchTokens =
      (payload['search'] as String).tokensForSearch().toList(growable: false);
  final filters = (payload['filters'] as List).cast<Map>();
  final sortField = payload['sortField'] as String?;
  final sortDirection = payload['sortDirection'] as String?;

  final groupedFilters = <String, List<Map>>{};
  for (final filter in filters) {
    final field = filter['field'] as String;
    groupedFilters.putIfAbsent(field, () => []).add(filter);
  }

  dynamic readFieldValue(Map rom, String field) {
    switch (field) {
      case 'rom.console':
        return rom['console'];
      case 'rom.name':
        return rom['name'];
      case 'isFavorite':
        return rom['isFavorite'];
      case 'playTimeMins':
        return rom['playTimeMins'];
      case 'addedAt':
        return rom['addedAtMs'];
      case 'lastPlayedAt':
        return rom['lastPlayedAtMs'];
      case 'filePath':
        return rom['filePath'];
      default:
        return null;
    }
  }

  bool matchesSearch(Map rom) {
    if (searchTokens.isEmpty) {
      return true;
    }

    final normalizedName = rom['normalizedName'] as String? ?? '';
    for (final token in searchTokens) {
      if (!normalizedName.contains(token)) {
        return false;
      }
    }
    return true;
  }

  bool hasValue(dynamic v) {
    if (v == null) return false;
    if (v == "None" || v == "Unknown") return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is Iterable) return v.isNotEmpty;
    return true;
  }

  bool matchesFilter(Map rom, Map filter) {
    final field = filter['field'] as String;
    switch (field) {
      case 'filePath':
        return (rom['filePath'] as String).isNotEmpty;
      case 'lastPlayedAt':
        return rom['lastPlayedAtMs'] == null;
      case 'isFavorite':
        return rom['isFavorite'] == true;
      default:
        final value = readFieldValue(rom, field);
        return value?.toString() == filter['value']?.toString();
    }
  }

  final filtered = <Map>[];
  for (final rom in roms) {
    if (!matchesSearch(rom)) {
      continue;
    }

    var matchedAllGroups = true;
    for (final entry in groupedFilters.entries) {
      final matchesGroup =
          entry.value.any((filter) => matchesFilter(rom, filter));
      if (!matchesGroup) {
        matchedAllGroups = false;
        break;
      }
    }

    if (matchedAllGroups) {
      filtered.add(rom);
    }
  }

  if (sortField != null) {
    filtered.sort((a, b) {
      final aValue = readFieldValue(a, sortField);
      final bValue = readFieldValue(b, sortField);

      final aHasValue = hasValue(aValue);
      final bHasValue = hasValue(bValue);

      if (aHasValue && !bHasValue) return -1;
      if (!aHasValue && bHasValue) return 1;
      if (aValue is Comparable && bValue is Comparable) {
        return sortDirection == ToolBarSortByType.ascending.name
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      }
      return 0;
    });
  }

  return filtered.map((rom) => rom['index'] as int).toList(growable: false);
}

enum quickFiltersTypes { none, all, installed, favorites }

var _initialToolbarValues = ToolbarValue<RomLibraryItem>(
    filters: [], search: '', sortBy: LibraryItemSorts.addedDateSort);

class LibraryPage extends StatefulWidget {
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  ToolbarValue<RomLibraryItem>? filterValues = _initialToolbarValues;
  final toolbarKey = GlobalKey<ToolbarState>();
  quickFiltersTypes selectedQuickFilter = quickFiltersTypes.all;
  Timer? _filterDebounce;
  int _filterGeneration = 0;
  int _lastLibraryRevision = -1;
  List<RomInfo> _filteredRoms = const [];
  List<ToolBarFilterGroup<RomLibraryItem>> _cachedFilters = const [];

  List<ToolBarFilterGroup<RomLibraryItem>> getFilters(
          List<RomLibraryItem> roms) =>
      [
        ToolBarFilterGroup(
          groupName: 'Consoles',
          filters: roms.map((e) => e.rom.console).toSet().map((console) {
            return LibraryItemFilters.consoleFilter(
                ConsoleService.getConsoleFromName(console)!);
          }).toList(),
        ),
        ToolBarFilterGroup(
          groupName: 'Availability',
          filters: [
            LibraryItemFilters.installedFilter,
            LibraryItemFilters.neverPlayerFilter,
            LibraryItemFilters.favoriteFilter
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

  @override
  void dispose() {
    _filterDebounce?.cancel();
    super.dispose();
  }

  void _scheduleFilter(
    List<RomLibraryItem> roms, {
    bool immediate = false,
  }) {
    _filterDebounce?.cancel();
    final delay = immediate ? Duration.zero : const Duration(milliseconds: 120);
    _filterDebounce = Timer(delay, () => _applyFilterAsync(roms));
  }

  Future<void> _applyFilterAsync(List<RomLibraryItem> roms) async {
    final generation = ++_filterGeneration;
    final payload = _buildLibraryFilterPayload(roms, filterValues);
    final filteredIndexes = await compute(_filterLibraryPayload, payload);

    if (!mounted || generation != _filterGeneration) {
      return;
    }

    final nextFiltered =
        filteredIndexes.map((index) => roms[index].rom).toList(growable: false);

    setState(() {
      _filteredRoms = nextFiltered;
    });
  }

  handleQuickFilterChanged(quickFiltersTypes filter) {
    switch (filter) {
      case quickFiltersTypes.all:
        toolbarKey.currentState?.setValues(ToolbarValue<RomLibraryItem>(
            search: filterValues?.search ?? '',
            sortBy: filterValues?.sortBy,
            filters: _initialToolbarValues.filters));
        break;
      case quickFiltersTypes.favorites:
        toolbarKey.currentState?.setValues(ToolbarValue<RomLibraryItem>(
            search: filterValues?.search ?? '',
            sortBy: filterValues?.sortBy,
            filters: [
              LibraryItemFilters.favoriteFilter,
            ]));
        break;
      case quickFiltersTypes.installed:
        toolbarKey.currentState?.setValues(ToolbarValue<RomLibraryItem>(
            search: filterValues?.search ?? '',
            sortBy: filterValues?.sortBy,
            filters: [LibraryItemFilters.installedFilter]));
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
    final libraryRevision =
        context.select<LibraryProvider, int>((p) => p.libraryItemsRevision);
    var libraryProvider = LibraryProvider.of(context);
    var appProvider = Provider.of<AppProvider>(context);
    var roms = libraryProvider.libraryItems;
    if (_lastLibraryRevision != libraryRevision) {
      _lastLibraryRevision = libraryRevision;
      _cachedFilters = getFilters(roms);
      _scheduleFilter(roms, immediate: true);
    } else if (_filteredRoms.isEmpty && roms.isNotEmpty) {
      _scheduleFilter(roms, immediate: true);
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              {LibraryImportDialog.show(context, handleAddToLibrary)},
          label: Text('Import Game'),
          icon: Icon(Icons.add)),
      appBar: Toolbar<RomLibraryItem>(
        onChanged: (values) {
          setState(() {
            filterValues = values;
            selectedQuickFilter = quickFiltersTypes.none;
          });
          _scheduleFilter(roms);
        },
        key: toolbarKey,
        settings: ToolbarSettings(
          title: "Library",
          filters: _cachedFilters,
          sorts: [
            LibraryItemSorts.romNameSort,
            LibraryItemSorts.addedDateSort,
            LibraryItemSorts.playedTimeSort,
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
              onViewModeChanged: (mode) {
                appProvider.setConsoleRomsItemType(mode);
              },
              initialViewMode: appProvider.romListItemType,
              roms: _filteredRoms,
            ),
    );
  }
}
