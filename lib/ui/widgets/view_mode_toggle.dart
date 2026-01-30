import 'package:flutter/material.dart';

enum ViewModeToggleMode {
  list,
  grid,
}

class ViewModeToggle extends StatelessWidget {
  final ViewModeToggleMode value;
  final ValueChanged<ViewModeToggleMode> onChanged;

  const ViewModeToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ViewModeToggleMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ViewModeToggleMode.list,
          icon: Icon(Icons.list, size: 18),
          label: Text('List'),
        ),
        ButtonSegment(
          value: ViewModeToggleMode.grid,
          icon: Icon(Icons.grid_view, size: 18),
          label: Text('Grid'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (newSelection) {
        onChanged(newSelection.first);
      },
    );
  }
}
