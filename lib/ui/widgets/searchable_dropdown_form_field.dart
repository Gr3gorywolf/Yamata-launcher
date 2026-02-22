import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:yamata_launcher/ui/widgets/focusable_element.dart';

class SearchableDropdownFormField<T> extends FormField<T> {
  SearchableDropdownFormField({
    super.key,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    InputDecoration decoration = const InputDecoration(),
    T? value,
    bool enabled = true,
    AutovalidateMode autovalidateMode = AutovalidateMode.disabled,
    FormFieldValidator<T>? validator,
    FormFieldSetter<T>? onSaved,
    Widget? hint,
    bool isExpanded = true,
    String searchHintText = 'Search...',
    double? menuMaxHeight = 520,
    bool disableRipple = true,
  }) : super(
          initialValue: value,
          validator: validator,
          onSaved: onSaved,
          enabled: enabled,
          autovalidateMode: autovalidateMode,
          builder: (FormFieldState<T> state) {
            final effectiveDecoration = decoration
                .applyDefaults(Theme.of(state.context).inputDecorationTheme)
                .copyWith(errorText: state.errorText);
            return _SearchableDropdownBody<T>(
              state: state,
              items: items,
              decoration: effectiveDecoration,
              hint: hint,
              isExpanded: isExpanded,
              enabled: enabled,
              onChanged: onChanged,
              searchHintText: searchHintText,
              menuMaxHeight: menuMaxHeight,
              disableRipple: disableRipple,
            );
          },
        );
}

class _SearchableDropdownBody<T> extends StatefulWidget {
  const _SearchableDropdownBody({
    required this.state,
    required this.items,
    required this.decoration,
    required this.onChanged,
    required this.enabled,
    required this.isExpanded,
    required this.searchHintText,
    required this.menuMaxHeight,
    required this.disableRipple,
    this.hint,
  });

  final FormFieldState<T> state;
  final List<DropdownMenuItem<T>> items;
  final InputDecoration decoration;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final bool isExpanded;
  final Widget? hint;
  final String searchHintText;
  final double? menuMaxHeight;
  final bool disableRipple;

  @override
  State<_SearchableDropdownBody<T>> createState() =>
      _SearchableDropdownBodyState<T>();
}

class _SearchableDropdownBodyState<T>
    extends State<_SearchableDropdownBody<T>> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DropdownMenuItem<T>? get _selectedItem {
    final currentValue = widget.state.value;
    if (currentValue == null) return null;

    try {
      return widget.items.firstWhere((e) => e.value == currentValue);
    } catch (_) {
      return null;
    }
  }

  String _itemLabel(DropdownMenuItem<T> item) {
    final child = item.child;
    if (child is Text) return child.data ?? child.textSpan?.toPlainText() ?? '';
    return item.value?.toString() ?? '';
  }

  Future<void> _openPicker() async {
    if (!widget.enabled) return;

    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SearchPickerSheet<T>(
        items: widget.items,
        selectedValue: widget.state.value,
        itemLabel: _itemLabel,
        searchCtrl: _searchCtrl,
        searchHintText: widget.searchHintText,
        maxHeight: widget.menuMaxHeight,
      ),
    );

    if (selected == null) return;

    widget.state.didChange(selected);
    widget.state.validate();

    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = _selectedItem;

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: FocusableElement(
        child: GestureDetector(
          onTap: _openPicker,
          behavior: HitTestBehavior.opaque,
          child: InputDecorator(
            decoration: widget.decoration.copyWith(
              enabled: widget.enabled,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            isEmpty: selectedItem == null,
            child: selectedItem == null
                ? null
                : DefaultTextStyle(
                    style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
                    child: selectedItem.child,
                  ),
          ),
        ),
      ),
    );
  }
}

class _SearchPickerSheet<T> extends StatefulWidget {
  const _SearchPickerSheet({
    required this.items,
    required this.selectedValue,
    required this.itemLabel,
    required this.searchCtrl,
    required this.searchHintText,
    required this.maxHeight,
  });

  final List<DropdownMenuItem<T>> items;
  final T? selectedValue;
  final String Function(DropdownMenuItem<T>) itemLabel;
  final TextEditingController searchCtrl;
  final String searchHintText;
  final double? maxHeight;

  @override
  State<_SearchPickerSheet<T>> createState() => _SearchPickerSheetState<T>();
}

class _SearchPickerSheetState<T> extends State<_SearchPickerSheet<T>> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.searchCtrl.text = '';
    widget.searchCtrl.addListener(_onSearchChange);
  }

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onSearchChange);
    super.dispose();
  }

  void _onSearchChange() {
    setState(() => _query = widget.searchCtrl.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items.where((e) {
            final label = widget.itemLabel(e).toLowerCase();
            return label.contains(_query);
          }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.40,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                widget.maxHeight ?? MediaQuery.of(context).size.height * .9,
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  color: Colors.grey.withOpacity(.4),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  controller: widget.searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: widget.searchHintText,
                    fillColor: Theme.of(context).colorScheme.onPrimary,
                    filled: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => widget.searchCtrl.clear(),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isSelected = item.value == widget.selectedValue;

                    return ListTile(
                      title: item.child,
                      trailing: isSelected
                          ? const Icon(Icons.check)
                          : const SizedBox(),
                      onTap: () => Navigator.of(context).pop(item.value),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ReactiveSearchableDropdownField<T> extends ReactiveFormField<T, T> {
  ReactiveSearchableDropdownField({
    super.key,
    String? formControlName,
    FormControl<T>? formControl,
    Map<String, ValidationMessageFunction>? validationMessages,
    ShowErrorsFunction<T>? showErrors,
    ControlValueAccessor<T, T>? valueAccessor,
    required List<DropdownMenuItem<T>> items,
    required InputDecoration decoration,
    ValueChanged<T?>? onChanged,
    Widget? hint,
    bool enabled = true,
    AutovalidateMode autovalidateMode = AutovalidateMode.disabled,
    bool isExpanded = true,
    String searchHintText = "Search...",
    double? menuMaxHeight = 520,
    bool disableRipple = true,
  }) : super(
          formControl: formControl,
          formControlName: formControlName,
          validationMessages: validationMessages,
          showErrors: showErrors,
          valueAccessor: valueAccessor,
          builder: (field) {
            return SearchableDropdownFormField<T>(
              value: field.value,
              key: ValueKey(field.value),
              items: items,
              decoration: decoration.copyWith(
                errorText: field.errorText,
              ),
              enabled: enabled && field.control.enabled,
              autovalidateMode: autovalidateMode,
              hint: hint,
              isExpanded: isExpanded,
              searchHintText: searchHintText,
              menuMaxHeight: menuMaxHeight,
              disableRipple: disableRipple,
              onChanged: (value) {
                field.didChange(value);

                field.control.markAsTouched();

                onChanged?.call(value);
              },
              validator: (_) {
                return null;
              },
            );
          },
        );
}
