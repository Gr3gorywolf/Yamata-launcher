import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/repository/roms_repository.dart';
import 'package:yamata_launcher/ui/widgets/rom_list.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:yamata_launcher/utils/toolbar_settings/filters/rom_info_filters.dart';
import 'package:yamata_launcher/utils/toolbar_settings/sorts/rom_info_sorts.dart';

Map<String, dynamic> _buildConsoleFilterPayload(
  List<RomInfo> roms,
  ToolbarValue<RomInfo>? toolbarValue,
  LibraryProvider libraryProvider,
  DownloadSourcesProvider downloadSourcesProvider,
) {
  return {
    'roms': roms
        .asMap()
        .entries
        .map((entry) => {
              'index': entry.key,
              'slug': entry.value.slug,
              'name': entry.value.name,
              'normalizedName': entry.value.name.normalizeForSearch(),
              'releaseDate': entry.value.releaseDate ?? '',
              'rating': entry.value.rating ?? '',
              'console': entry.value.console,
              'onLibrary':
                  libraryProvider.getLibraryItem(entry.value.slug) != null,
              'downloaded': libraryProvider
                      .getLibraryItem(entry.value.slug)
                      ?.downloadedAt !=
                  null,
              'downloadAvailable':
                  downloadSourcesProvider.isRomCompilingDownloadSources(
                        entry.value.slug,
                      ) ||
                      downloadSourcesProvider
                          .getRomSources(entry.value.slug)
                          .isNotEmpty,
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

List<int> _filterConsolePayload(Map<String, dynamic> payload) {
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
      case 'name':
        return rom['name'];
      case 'releaseDate':
        return rom['releaseDate'];
      case 'rating':
        return rom['rating'];
      case 'console':
        return rom['console'];
      default:
        return null;
    }
  }

  bool hasValue(dynamic v) {
    if (v == null) return false;
    if (v == "None" || v == "Unknown") return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is Iterable) return v.isNotEmpty;
    return true;
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

  bool matchesFilter(Map rom, Map filter) {
    switch (filter['field']) {
      case 'isOnLibrary':
        return rom['onLibrary'] == true;
      case 'isDownloaded':
        return rom['downloaded'] == true;
      case 'isNotDownloaded':
        return rom['downloaded'] != true;
      case 'isDownloadAvailable':
        return rom['downloadAvailable'] == true;
      default:
        final value = readFieldValue(rom, filter['field'] as String);
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

enum quickFiltersTypes { none, all, download_available, on_library }

class ConsoleRomsPage extends StatefulWidget {
  Console console;
  List<RomInfo>? infos;
  ConsoleRomsPage(this.console, {this.infos});
  @override
  _ConsoleRomsPageState createState() => _ConsoleRomsPageState();
}

class _ConsoleRomsPageState extends State<ConsoleRomsPage> {
  List<RomInfo>? _roms = [];
  final toolbarKey = GlobalKey<ToolbarState>();
  bool _isLoading = false;
  ToolbarValue<RomInfo>? filterValues = null;
  quickFiltersTypes selectedQuickFilter = quickFiltersTypes.all;
  Timer? _filterDebounce;
  int _filterGeneration = 0;
  int _lastLibraryRevision = -1;
  int _lastSourcesRevision = -1;
  List<RomInfo> _filteredRoms = const [];

  handleQuickFilterChanged(quickFiltersTypes filter) {
    switch (filter) {
      case quickFiltersTypes.all:
        toolbarKey.currentState?.setValues(ToolbarValue<RomInfo>(
            search: filterValues?.search ?? "",
            sortBy: filterValues?.sortBy,
            filters: []));
        break;
      case quickFiltersTypes.on_library:
        toolbarKey.currentState?.setValues(ToolbarValue<RomInfo>(
            search: filterValues?.search ?? "",
            sortBy: filterValues?.sortBy,
            filters: [
              RomInfoFilters.isOnLibraryFilter,
            ]));
        break;
      case quickFiltersTypes.download_available:
        toolbarKey.currentState?.setValues(ToolbarValue<RomInfo>(
            search: filterValues?.search ?? '',
            sortBy: filterValues?.sortBy,
            filters: [
              RomInfoFilters.isDownloadAvailableFilter,
            ]));
        break;
      default:
        break;
    }
    setState(() {
      selectedQuickFilter = filter;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.infos == null) {
      fetchRoms();
    } else {
      _roms = widget.infos;
      _filteredRoms = List<RomInfo>.unmodifiable(widget.infos ?? const []);
    }
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    super.dispose();
  }

  void _scheduleFilter({
    bool immediate = false,
  }) {
    _filterDebounce?.cancel();
    final delay = immediate ? Duration.zero : const Duration(milliseconds: 120);
    _filterDebounce = Timer(delay, _applyFilterAsync);
  }

  Future<void> _applyFilterAsync() async {
    final roms = _roms ?? const <RomInfo>[];
    final libraryProvider = context.read<LibraryProvider>();
    final downloadSourcesProvider = context.read<DownloadSourcesProvider>();
    final generation = ++_filterGeneration;
    final payload = _buildConsoleFilterPayload(
      roms,
      filterValues,
      libraryProvider,
      downloadSourcesProvider,
    );
    final filteredIndexes = await compute(_filterConsolePayload, payload);

    if (!mounted || generation != _filterGeneration) {
      return;
    }

    setState(() {
      _filteredRoms =
          filteredIndexes.map((index) => roms[index]).toList(growable: false);
    });
  }

  void fetchRoms() async {
    setState(() {
      _isLoading = true;
    });
    var roms = await new RomsRepository().fetchRoms(widget.console);
    var downloadSourcesProvider =
        Provider.of<DownloadSourcesProvider>(context, listen: false);
    downloadSourcesProvider.compileRomDownloadSources(roms);
    setState(() {
      _roms = roms;
      _filteredRoms = List<RomInfo>.unmodifiable(roms);
      _isLoading = false;
    });
    _scheduleFilter(immediate: true);
  }

  @override
  Widget build(BuildContext context) {
    final libraryRevision =
        context.select<LibraryProvider, int>((p) => p.libraryItemsRevision);
    final sourcesRevision = context.select<DownloadSourcesProvider, int>(
      (p) => p.romSourcesRevision,
    );
    if (_lastLibraryRevision != libraryRevision ||
        _lastSourcesRevision != sourcesRevision) {
      _lastLibraryRevision = libraryRevision;
      _lastSourcesRevision = sourcesRevision;
      _scheduleFilter(immediate: true);
    } else if (_filteredRoms.isEmpty && (_roms?.isNotEmpty ?? false)) {
      _scheduleFilter(immediate: true);
    }

    var appProvider = Provider.of<AppProvider>(context);
    return Scaffold(
      appBar: Toolbar<RomInfo>(
        key: toolbarKey,
        onChanged: (values) {
          setState(() {
            filterValues = values;
            selectedQuickFilter = quickFiltersTypes.none;
          });
          _scheduleFilter();
        },
        initialValues: ToolbarValue<RomInfo>(
            filters: [], search: '', sortBy: RomInfoSorts.nameSort),
        settings: ToolbarSettings(title: widget.console.name, sorts: [
          RomInfoSorts.nameSort,
          RomInfoSorts.releaseDateSort,
          RomInfoSorts.popularitySort,
        ], filters: [
          ToolBarFilterGroup(
            groupName: "Availability",
            filters: [
              RomInfoFilters.isOnLibraryFilter,
              RomInfoFilters.isDownloadedFilter,
              RomInfoFilters.isNotDownloadedFilter,
              RomInfoFilters.isDownloadAvailableFilter,
            ],
          )
        ]),
      ),
      body: RomList(
        isLoading: this._isLoading,
        roms: _filteredRoms,
        topRightChild: SegmentedButton<quickFiltersTypes>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: quickFiltersTypes.all,
              icon: Icon(Icons.list, size: 18),
            ),
            ButtonSegment(
              value: quickFiltersTypes.download_available,
              icon: Icon(Icons.cloud_download_rounded, size: 18),
            ),
            ButtonSegment(
              value: quickFiltersTypes.on_library,
              icon: Icon(Icons.collections_bookmark_rounded, size: 18),
            ),
          ],
          selected: {selectedQuickFilter},
          onSelectionChanged: (newSelection) {
            handleQuickFilterChanged(newSelection.first);
          },
        ),
        initialViewMode: appProvider.romListItemType,
        onViewModeChanged: (mode) {
          appProvider.setConsoleRomsItemType(mode);
        },
      ),
    );
  }
}
