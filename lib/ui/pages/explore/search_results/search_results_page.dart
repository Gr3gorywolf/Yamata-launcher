import 'package:flutter/material.dart';
import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/repository/roms_repository.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/widgets/rom_list.dart';
import 'package:yamata_launcher/ui/widgets/toolbar.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/utils/cached_filter_results.dart';
import 'package:yamata_launcher/utils/plain_text_search.dart';

DateTime? _nextRevalidation = null;

class SearchResultsPage extends StatefulWidget {
  String searchQuery = "";
  SearchResultsPage(this.searchQuery);
  @override
  _SearchResultsPageState createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  List<RomInfo>? _roms = [];
  final _filteredRomsCache = CachedFilterResults<RomInfo, RomInfo>();
  bool _isLoading = false;
  double loadingProgress = 0;
  ToolbarValue<RomInfo>? filterValues = null;

  @override
  void initState() {
    super.initState();
    if (mounted) {
      fetchRoms();
    }
  }

  Future<List<RomInfo>> downloadAndFilterRoms(String query) async {
    final result = <RomInfo>[];

    var useCache = _nextRevalidation != null &&
        DateTime.now().isBefore(_nextRevalidation!);

    final consoles = ConsoleConstants.defaultConsoles;
    final concurrency = 20;
    int index = 0;
    Future<void> worker() async {
      while (index < consoles.length) {
        final current = index++;
        final console = consoles[current];

        var roms =
            await RomsRepository().fetchRoms(console, forceCache: useCache);

        for (var rom in roms) {
          if (PlainTextSearch.matches(query, rom.name)) {
            result.add(rom);
          }
        }

        roms.clear();

        if (mounted) {
          setState(() {
            loadingProgress += 1 / consoles.length * 100;
          });
        }
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));

    _nextRevalidation = DateTime.now().add(Duration(hours: 1));

    return result;
  }

  void fetchRoms() async {
    setState(() {
      _isLoading = true;
    });

    var filteredLocal = await downloadAndFilterRoms(widget.searchQuery);

    var externalRoms =
        await RomsRepository().searchFromExternalSources(widget.searchQuery);

    var importedRoms =
        await RomsRepository().getImportedRoms(widget.searchQuery);

    final map = <String, RomInfo>{};

    for (final e in filteredLocal) {
      map[e.slug] = e;
    }
    for (final e in externalRoms) {
      map[e.slug] = e;
    }
    for (final e in importedRoms) {
      map[e.slug] = e;
    }

    var uniqueList = map.values.toList();

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
    final downloadSourcesProvider =
        Provider.of<DownloadSourcesProvider>(context, listen: false);
    final libraryProvider =
        Provider.of<LibraryProvider>(context, listen: false);
    final libraryVersion =
        context.select<LibraryProvider, int>((provider) => provider.version);
    final downloadSourcesVersion = context
        .select<DownloadSourcesProvider, int>((provider) => provider.version);
    final filteredRoms = _filteredRomsCache.resolve(
      source: _roms,
      toolbarValue: filterValues,
      revisionKey: (_roms, libraryVersion, downloadSourcesVersion),
      map: (rom) => rom,
    );

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
              if (_roms != null)
                ToolBarFilterGroup(
                  groupName: 'Consoles',
                  filters: (_roms ?? [])
                      .map((e) => e.console)
                      .toSet()
                      .map((console) {
                    var consoleInfo =
                        ConsoleService.getConsoleFromName(console);
                    return ToolBarFilterElement<RomInfo>(
                        label: consoleInfo?.name ?? "",
                        field: 'console',
                        value: consoleInfo?.slug ?? "");
                  }).toList(),
                ),
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
      body: Builder(builder: (context) {
        if (_isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: loadingProgress / 100),
              ],
            ),
          );
        }
        return RomList(
          isLoading: this._isLoading,
          roms: filteredRoms,
          showConsole: true,
          initialViewMode: appProvider.romListItemType,
          onViewModeChanged: (mode) {
            appProvider.setConsoleRomsItemType(mode);
          },
        );
      }),
    );
  }
}
