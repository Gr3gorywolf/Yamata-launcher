import 'package:flutter/material.dart';

class SelectableChips<T> extends StatelessWidget {
  final List<ChipOption<T>> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final bool allowDeselect;

  const SelectableChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.allowDeselect = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = option.value == value;

        return ChoiceChip(
          label: Text(option.label),
          selected: isSelected,
          onSelected: (_) {
            if (isSelected && allowDeselect) {
              onChanged(null);
            } else {
              onChanged(option.value);
            }
          },
          showCheckmark: false,
          avatar: isSelected
              ? Icon(
                  Icons.check,
                  size: 18,
                  color: theme.colorScheme.onPrimary,
                )
              : null,
          shape: StadiumBorder(
            side: isSelected
                ? BorderSide.none
                : BorderSide(color: theme.colorScheme.primary),
          ),
          backgroundColor: Colors.transparent,
          selectedColor: theme.colorScheme.primary,
          labelStyle: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
        );
      }).toList(),
    );
  }
}

class ChipOption<T> {
  final String label;
  final T value;

  ChipOption({
    required this.label,
    required this.value,
  });
}
