import 'package:collection/collection.dart';
import 'package:sembast/sembast.dart';
import 'package:yamata_launcher/models/contracts/json_serializable.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/utils/plain_text_search.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class FilterHelpers {
  static _getValueByPath(Map<String, dynamic> json, String path) {
    dynamic current = json;

    for (final key in path.split('.')) {
      if (current is Map<String, dynamic> && current.containsKey(key)) {
        current = current[key];
      } else {
        return null;
      }
    }

    return current;
  }

  static List<T> handleDynamicFilter<T extends JsonSerializable>(
    List<T> subjects,
    ToolbarValue<T> toolbarValue, {
    String nameField = 'name',
  }) {
    List<T> filteredSubjects = subjects;
    final sort = toolbarValue.sortBy;
    if (toolbarValue.search.isNotEmpty) {
      var filterValues = filteredSubjects.map((subject) {
        return _getValueByPath(subject.toJson(), nameField)?.toString() ?? "";
      }).toList();
      var filterResults =
          PlainTextSearch.search(toolbarValue.search, filterValues)
              .map((e) => e.item)
              .toList();
      filteredSubjects = filteredSubjects.where((subject) {
        final value = _getValueByPath(subject.toJson(), nameField)?.toString();
        return filterResults.contains(value);
      }).toList();
    }

    if (toolbarValue.filters.isNotEmpty) {
      final Map<String, List<ToolBarFilterElement<T>>> grouped = {};

      for (final f in toolbarValue.filters) {
        grouped.putIfAbsent(f.field, () => []).add(f);
      }

      filteredSubjects = filteredSubjects.where((subject) {
        for (final entry in grouped.entries) {
          final groupFilters = entry.value;
          final groupMatch = groupFilters.any((f) {
            if (f.matcher != null) return f.matcher!(subject);
            final value = _getValueByPath(subject.toJson(), f.field);
            return value?.toString() == f.value;
          });

          if (!groupMatch) {
            return false;
          }
        }
        return true;
      }).toList();
    }

    if (sort != null) {
      filteredSubjects.sort((a, b) {
        final aValue = _getValueByPath(a.toJson(), sort.field);
        final bValue = _getValueByPath(b.toJson(), sort.field);

        if (aValue is Comparable && bValue is Comparable) {
          return sort.value == ToolBarSortByType.ascending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        }
        return 0;
      });
    }

    return filteredSubjects;
  }
}
