import 'package:yamata_launcher/models/toolbar_elements.dart';

class RomInfoSorts {
  static var nameSort = ToolBarSortByElement(
      label: 'Name', field: 'name', value: ToolBarSortByType.ascending);

  static var releaseDateSort = ToolBarSortByElement(
      label: 'Release Date',
      field: 'releaseDate',
      value: ToolBarSortByType.ascending);

  static var popularitySort = ToolBarSortByElement(
      label: 'Popularity', field: 'rating', value: ToolBarSortByType.ascending);
}
