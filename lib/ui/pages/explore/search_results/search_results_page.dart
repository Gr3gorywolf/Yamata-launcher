import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';
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
import 'package:yamata_launcher/utils/filter_helpers.dart';
import 'package:yamata_launcher/utils/plain_text_search.dart';

class SearchResultsPage extends StatefulWidget {
  String searchQuery = "";
  SearchResultsPage(this.searchQuery);
  @override
  _SearchResultsPageState createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  List<RomInfo>? _roms = [];
  bool _isLoading = false;
  ToolbarValue<RomInfo>? filterValues = null;

  List<RomInfo> get filteredRoms {
    if (_roms == null) return [];
    if (filterValues == null) return _roms!;
    return FilterHelpers.handleDynamicFilter<RomInfo>(_roms!, filterValues!);
  }

  @override
  void initState() {
    super.initState();
    fetchRoms();
  }

  void fetchRoms() async {
    setState(() {
      _isLoading = true;
    });
    _roms = await new RomsRepository().searchRoms(widget.searchQuery);
    var externalRoms = await new RomsRepository()
        .searchFromExternalSources(widget.searchQuery);
    var importedRoms =
        await new RomsRepository().getImportedRoms(widget.searchQuery);

    print(
        "Found ${_roms!.length} local roms, ${externalRoms.length} external roms, ${importedRoms.length} imported roms for query '${widget.searchQuery}'");
    _roms!.addAll(externalRoms);
    _roms!.addAll(importedRoms);
    final map = <String, RomInfo>{};

    for (final e in _roms!) {
      map[e.slug] = e;
    }

    final uniqueList = map.values.toList();
    var downloadSourcesProvider =
        Provider.of<DownloadSourcesProvider>(context, listen: false);
    downloadSourcesProvider.compileRomDownloadSources(uniqueList);
    setState(() {
      _roms = uniqueList;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    var appProvider = Provider.of<AppProvider>(context);
    var downloadSourcesProvider = Provider.of<DownloadSourcesProvider>(context);
    var libraryProvider = Provider.of<LibraryProvider>(context);
    return Scaffold(
      appBar: Toolbar<RomInfo>(
        onChanged: (values) {
          setState(() {
            filterValues = values;
          });
        },
        initialValues: ToolbarValue<RomInfo>(
            filters: [],
            search: '',
            sortBy: ToolBarSortByElement(
                label: 'Name',
                field: 'name',
                value: ToolBarSortByType.ascending)),
        settings: ToolbarSettings(
            title: "Search Results for '${widget.searchQuery}'",
            disableSearch: true,
            sorts: [
              ToolBarSortByElement(
                  label: 'Name',
                  field: 'name',
                  value: ToolBarSortByType.ascending),
              ToolBarSortByElement(
                  label: 'Release Date',
                  field: 'releaseDate',
                  value: ToolBarSortByType.ascending),
            ],
            filters: [
              ToolBarFilterGroup(
                groupName: "Availability",
                filters: [
                  ToolBarFilterElement(
                      label: "On Library",
                      field: "isDownloaded",
                      value: "",
                      matcher: (romInfo) {
                        var libItem =
                            libraryProvider.getLibraryItem(romInfo.slug);
                        return libItem != null;
                      }),
                  ToolBarFilterElement(
                      label: "Downloaded",
                      field: "isDownloaded",
                      value: "",
                      matcher: (romInfo) {
                        var libItem =
                            libraryProvider.getLibraryItem(romInfo.slug);
                        return libItem != null && libItem.downloadedAt != null;
                      }),
                  ToolBarFilterElement(
                    label: "Not Downloaded",
                    field: "isNotDownloaded",
                    value: "",
                    matcher: (romInfo) {
                      var libItem =
                          libraryProvider.getLibraryItem(romInfo.slug);
                      return libItem == null || libItem.downloadedAt == null;
                    },
                  ),
                  ToolBarFilterElement(
                    label: "Download Available",
                    field: "isDownloadAvailable",
                    value: "",
                    matcher: (romInfo) {
                      return downloadSourcesProvider
                              .isRomCompilingDownloadSources(romInfo.slug) ||
                          downloadSourcesProvider
                              .getRomSources(romInfo.slug)
                              .isNotEmpty;
                    },
                  ),
                ],
              )
            ]),
      ),
      body: RomList(
        isLoading: this._isLoading,
        roms: filteredRoms,
        showConsole: true,
        initialViewMode: appProvider.romListItemType,
        onViewModeChanged: (mode) {
          appProvider.setConsoleRomsItemType(mode);
        },
      ),
    );
  }
}
