import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';

class RomInfoFilters {
  static LibraryProvider get _libraryProvider =>
      Provider.of<LibraryProvider>(navigatorContext!, listen: false);

  static DownloadSourcesProvider get downloadSourcesProvider =>
      Provider.of<DownloadSourcesProvider>(navigatorContext!, listen: false);
  static var isOnLibraryFilter = ToolBarFilterElement<RomInfo>(
    label: "On Library",
    field: "isOnLibrary",
    value: "",
    matcher: (romInfo) {
      var libItem = _libraryProvider.getLibraryItem(romInfo.slug);
      return libItem != null;
    },
  );

  static var isDownloadedFilter = ToolBarFilterElement<RomInfo>(
      label: "Downloaded",
      field: "isDownloaded",
      value: "",
      matcher: (romInfo) {
        var libItem = _libraryProvider.getLibraryItem(romInfo.slug);
        return libItem != null && libItem.downloadedAt != null;
      });

  static var isNotDownloadedFilter = ToolBarFilterElement<RomInfo>(
    label: "Not Downloaded",
    field: "isNotDownloaded",
    value: "",
    matcher: (romInfo) {
      var libItem = _libraryProvider.getLibraryItem(romInfo.slug);
      return libItem == null || libItem.downloadedAt == null;
    },
  );

  static var isDownloadAvailableFilter = ToolBarFilterElement<RomInfo>(
    label: "Download Available",
    field: "isDownloadAvailable",
    value: "",
    matcher: (romInfo) {
      return downloadSourcesProvider
              .isRomCompilingDownloadSources(romInfo.slug) ||
          downloadSourcesProvider.getRomSources(romInfo.slug).isNotEmpty;
    },
  );
}
