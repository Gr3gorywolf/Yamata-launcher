import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/repository/roms_repository.dart';
import 'package:yamata_launcher/ui/widgets/rom_list.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';
import 'package:provider/provider.dart';

import '../../../utils/filter_helpers.dart';

enum quickFiltersTypes { none, all, download_available, on_library }

class ConsoleRomsPage extends StatefulWidget {
  Console console;
  List<RomInfo>? infos;
  ConsoleRomsPage(this.console, {this.infos});
  @override
  _ConsoleRomsPageState createState() => _ConsoleRomsPageState();
}

class _ConsoleRomsPageState extends State<ConsoleRomsPage> {
  String _searchQuery = "";
  List<RomInfo>? _roms = [];
  final toolbarKey = GlobalKey<ToolbarState>();
  bool _isLoading = false;
  ToolbarValue? filterValues = null;
  quickFiltersTypes selectedQuickFilter = quickFiltersTypes.all;

  List<RomInfo> get filteredRoms {
    if (_roms == null) return [];
    if (filterValues == null) return _roms!;
    return FilterHelpers.handleDynamicFilter<RomInfo>(_roms!, filterValues!);
  }

  handleQuickFilterChanged(quickFiltersTypes filter) {
    switch (filter) {
      case quickFiltersTypes.all:
        toolbarKey.currentState?.setValues(ToolbarValue(
            search: filterValues?.search ?? "",
            sortBy: filterValues?.sortBy,
            filters: []));
        break;
      case quickFiltersTypes.on_library:
        toolbarKey.currentState?.setValues(ToolbarValue(
            search: filterValues?.search ?? "",
            sortBy: filterValues?.sortBy,
            filters: [
              ToolBarFilterElement(
                label: "On Library",
                field: "isOnLibrary",
                value: "",
                matcher: (romInfo) {
                  var libraryProvider =
                      Provider.of<LibraryProvider>(context, listen: false);
                  var libItem = libraryProvider.getLibraryItem(romInfo.slug);
                  return libItem != null;
                },
              ),
            ]));
        break;
      case quickFiltersTypes.download_available:
        toolbarKey.currentState?.setValues(ToolbarValue(
            search: filterValues?.search ?? '',
            sortBy: filterValues?.sortBy,
            filters: [
              ToolBarFilterElement(
                label: "Download Available",
                field: "isDownloadAvailable",
                value: "",
                matcher: (romInfo) {
                  var downloadSourcesProvider =
                      Provider.of<DownloadSourcesProvider>(context,
                          listen: false);
                  return downloadSourcesProvider
                          .isRomCompilingDownloadSources(romInfo.slug) ||
                      downloadSourcesProvider
                          .getRomSources(romInfo.slug)
                          .isNotEmpty;
                },
              ),
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
    }
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
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    var appProvider = Provider.of<AppProvider>(context);
    var downloadSourcesProvider = Provider.of<DownloadSourcesProvider>(context);
    var libraryProvider = Provider.of<LibraryProvider>(context);
    return Scaffold(
      appBar: Toolbar(
        key: toolbarKey,
        onChanged: (values) {
          setState(() {
            filterValues = values;
            selectedQuickFilter = quickFiltersTypes.none;
          });
        },
        initialValues: ToolbarValue(
            filters: [],
            search: '',
            sortBy: ToolBarSortByElement(
                label: 'Name',
                field: 'name',
                value: ToolBarSortByType.ascending)),
        settings: ToolbarSettings(title: widget.console.name, sorts: [
          ToolBarSortByElement(
              label: 'Name', field: 'name', value: ToolBarSortByType.ascending),
          ToolBarSortByElement(
              label: 'Release Date',
              field: 'releaseDate',
              value: ToolBarSortByType.ascending),
        ], filters: [
          ToolBarFilterGroup(
            groupName: "Availability",
            filters: [
              ToolBarFilterElement(
                label: "On Library",
                field: "isOnLibrary",
                value: "",
                matcher: (romInfo) {
                  var libraryProvider =
                      Provider.of<LibraryProvider>(context, listen: false);
                  var libItem = libraryProvider.getLibraryItem(romInfo.slug);
                  return libItem != null;
                },
              ),
              ToolBarFilterElement(
                  label: "Downloaded",
                  field: "isDownloaded",
                  value: "",
                  matcher: (romInfo) {
                    var libItem = libraryProvider.getLibraryItem(romInfo.slug);
                    return libItem != null && libItem.downloadedAt != null;
                  }),
              ToolBarFilterElement(
                label: "Not Downloaded",
                field: "isNotDownloaded",
                value: "",
                matcher: (romInfo) {
                  var libItem = libraryProvider.getLibraryItem(romInfo.slug);
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
        initialViewMode: appProvider.consoleRomsItemType,
        onViewModeChanged: (mode) {
          appProvider.setConsoleRomsItemType(mode);
        },
      ),
    );
  }
}
