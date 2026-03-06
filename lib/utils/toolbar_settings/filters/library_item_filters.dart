import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';

class LibraryItemFilters {
  static var consoleFilter = (Console console) =>
      ToolBarFilterElement<RomLibraryItem>(
          label: console.name ?? "",
          field: 'rom.console',
          value: console.slug ?? "");

  static var installedFilter = ToolBarFilterElement<RomLibraryItem>(
      label: "Installed",
      field: 'filePath',
      value: "true",
      matcher: (RomLibraryItem libraryItem) {
        return libraryItem.filePath != null && libraryItem.filePath!.isNotEmpty;
      });

  static var neverPlayerFilter = ToolBarFilterElement<RomLibraryItem>(
      label: "Never Played",
      field: 'lastPlayedAt',
      value: "true",
      matcher: (rom) {
        return rom.lastPlayedAt == null;
      });

  static var favoriteFilter = ToolBarFilterElement<RomLibraryItem>(
      label: "Favorite", field: 'isFavorite', value: "true");
}
