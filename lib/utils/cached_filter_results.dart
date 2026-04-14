import 'package:yamata_launcher/models/contracts/json_serializable.dart';
import 'package:yamata_launcher/models/toolbar_elements.dart';
import 'package:yamata_launcher/utils/filter_helpers.dart';

// This class is responsible for caching the results of filtering operations based on a revision key and toolbar values.
class CachedFilterResults<T extends JsonSerializable, R> {
  Object? _lastRevisionKey;
  String _lastToolbarSignature = '';
  List<R> _cachedResults = const [];
  // The resolve method checks if the filtering needs to be recomputed based on the revision key and toolbar signature.
  List<R> resolve({
    required List<T>? source,
    required ToolbarValue<T>? toolbarValue,
    required Object? revisionKey,
    required R Function(T item) map,
    String nameField = 'name',
  }) {
    final items = source ?? const [];
    final toolbarSignature = FilterHelpers.getToolbarSignature(toolbarValue);
    final shouldRecompute = _lastRevisionKey != revisionKey ||
        _lastToolbarSignature != toolbarSignature;

    if (!shouldRecompute) {
      return _cachedResults;
    }

    final filteredItems = toolbarValue == null
        ? List<T>.of(items)
        : FilterHelpers.handleDynamicFilter<T>(
            items,
            toolbarValue,
            nameField: nameField,
          );

    _cachedResults = filteredItems.map(map).toList(growable: false);
    _lastRevisionKey = revisionKey;
    _lastToolbarSignature = toolbarSignature;

    return _cachedResults;
  }

  void clear() {
    _lastRevisionKey = null;
    _lastToolbarSignature = '';
    _cachedResults = const [];
  }
}
