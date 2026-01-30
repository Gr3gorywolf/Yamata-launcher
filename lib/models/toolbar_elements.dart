class ToolbarSettings<T> {
  String? searchHint = "Search...";
  String? title = "Search";
  bool disableSearch = false;
  List<ToolBarSortByElement>? sorts = [];
  List<ToolBarFilterGroup<T>>? filters = [];
  ToolbarSettings(
      {this.sorts,
      this.filters,
      this.title,
      this.searchHint,
      this.disableSearch = false});
}

class ToolbarValue<T> {
  String search;
  ToolBarSortByElement? sortBy;
  List<ToolBarFilterElement<T>> filters;
  ToolbarValue({required this.search, this.sortBy, required this.filters});
}

enum ToolBarSortByType { ascending, descending }

class ToolBarSortByElement<T> {
  String label;
  String field;
  ToolBarSortByType value;
  ToolBarSortByElement(
      {required this.label, required this.field, required this.value});
}

class ToolBarFilterGroup<T> {
  String groupName;
  List<ToolBarFilterElement<T>> filters;
  ToolBarFilterGroup({required this.groupName, required this.filters});
}

class ToolBarFilterElement<T> {
  String label;
  String field;
  String value;
  bool Function(T subject)? matcher;

  ToolBarFilterElement({
    required this.label,
    required this.field,
    required this.value,
    this.matcher,
  });
}
