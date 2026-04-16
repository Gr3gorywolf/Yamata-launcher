import 'package:flutter/material.dart';

class SelectableChips<T> extends StatelessWidget {
  final List<ChipOption<T>> options;

  final List<T> values;

  final ValueChanged<List<T>> onChanged;

  final bool multiple;

  final bool allowDeselect;

  const SelectableChips({
    super.key,
    required this.options,
    required this.values,
    required this.onChanged,
    this.multiple = true,
    this.allowDeselect = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = values.contains(option.value);

        return ChoiceChip(
          label: Text(option.label),
          selected: isSelected,
          onSelected: (_) {
            List<T> newValues = List<T>.from(values);

            if (multiple) {
              // -------------------------
              // MULTIPLE MODE
              // -------------------------
              if (isSelected) {
                if (!allowDeselect) return;
                newValues.remove(option.value);
              } else {
                newValues.add(option.value);
              }
            } else {
              // -------------------------
              // SINGLE MODE
              // -------------------------
              if (isSelected) {
                if (!allowDeselect) return;
                newValues.clear();
              } else {
                newValues = [option.value];
              }
            }

            onChanged(newValues);
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
