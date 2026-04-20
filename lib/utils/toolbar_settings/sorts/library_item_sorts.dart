import 'package:yamata_launcher/models/toolbar_elements.dart';

class LibraryItemSorts {
  static var addedDateSort = ToolBarSortByElement(
      label: 'Added Date',
      field: 'addedAt',
      value: ToolBarSortByType.ascending);

  static var romNameSort = ToolBarSortByElement(
      label: 'Name', field: 'rom.name', value: ToolBarSortByType.ascending);

  static var playedTimeSort = ToolBarSortByElement(
      label: 'Played time',
      field: 'playTimeMins',
      value: ToolBarSortByType.ascending);

  static var lastPlayedSort = ToolBarSortByElement(
      label: 'Last Played',
      field: 'lastPlayedAt',
      value: ToolBarSortByType.ascending);
}
