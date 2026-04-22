import 'package:yamata_launcher/models/toolbar_elements.dart';

class RomInfoSorts {
  static var nameSort = ToolBarSortByElement(
      label: 'Name',
      field: 'name',
      defaultSort: ToolBarSortByType.ascending,
      value: ToolBarSortByType.ascending);

  static var releaseDateSort = ToolBarSortByElement(
      label: 'Release Date',
      field: 'releaseDateTime',
      defaultSort: ToolBarSortByType.descending,
      value: ToolBarSortByType.descending);

  static var popularitySort = ToolBarSortByElement(
      label: 'Popularity',
      field: 'rating',
      defaultSort: ToolBarSortByType.descending,
      value: ToolBarSortByType.descending);
}
