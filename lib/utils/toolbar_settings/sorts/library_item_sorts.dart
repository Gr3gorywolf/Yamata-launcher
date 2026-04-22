import 'package:yamata_launcher/models/toolbar_elements.dart';

class LibraryItemSorts {
  static var addedDateSort = ToolBarSortByElement(
      label: 'Added Date',
      field: 'addedAt',
      defaultSort: ToolBarSortByType.descending,
      value: ToolBarSortByType.descending);

  static var romNameSort = ToolBarSortByElement(
      label: 'Name',
      field: 'rom.name',
      defaultSort: ToolBarSortByType.ascending,
      value: ToolBarSortByType.ascending);

  static var playedTimeSort = ToolBarSortByElement(
      label: 'Played time',
      field: 'playTimeMins',
      defaultSort: ToolBarSortByType.descending,
      value: ToolBarSortByType.descending);

  static var lastPlayedSort = ToolBarSortByElement(
      label: 'Last Played',
      field: 'lastPlayedAt',
      defaultSort: ToolBarSortByType.descending,
      value: ToolBarSortByType.descending);
}
