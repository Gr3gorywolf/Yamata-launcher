import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/argument_group.dart';
import 'package:yamata_launcher/ui/widgets/selectable_chips.dart';

class ArgumentsPickerDialog extends StatefulWidget {
  final List<ArgumentGroup> argumentGroups;
  final String? title;
  const ArgumentsPickerDialog(
      {super.key, required this.argumentGroups, this.title});

  @override
  State<ArgumentsPickerDialog> createState() => _ArgumentsPickerDialogState();

  static Future<ArgumentsPickerDialogResult> show(BuildContext context,
      {required List<ArgumentGroup> argumentGroups, String? title}) async {
    var result = await showDialog<ArgumentsPickerDialogResult>(
        context: context,
        builder: (_) {
          return ArgumentsPickerDialog(
              argumentGroups: argumentGroups, title: title);
        });
    return result ?? ArgumentsPickerDialogResult([]);
  }
}

class _ArgumentsPickerDialogState extends State<ArgumentsPickerDialog> {
  Map<String, List<Argument>> selectedArguments = {};
  bool replaceArgs = true;
  List<String> get allSelectedArgs => selectedArguments.values
      .expand((args) => args)
      .map((arg) => arg.value)
      .toList();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title ?? 'Build Arguments'),
      content: Container(
        height: 400,
        width: MediaQuery.of(context).size.width / 5,
        constraints: BoxConstraints(maxHeight: 400, maxWidth: 500),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.argumentGroups.length,
                itemBuilder: (context, index) {
                  var group = widget.argumentGroups[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.name,
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 5),
                        SelectableChips<Argument>(
                            options: group.arguments
                                .map((arg) => ChipOption<Argument>(
                                    label: arg.name, value: arg))
                                .toList(),
                            values: selectedArguments[group.name] ?? [],
                            multiple: !group.singleSelect,
                            onChanged: (values) {
                              setState(() {
                                selectedArguments[group.name] = values;
                              });
                            })
                      ],
                    ),
                  );
                },
              ),
            ),
            CheckboxListTile(
              value: replaceArgs,
              onChanged: (checked) => {
                setState(() {
                  replaceArgs = checked ?? false;
                })
              },
              title: Text(
                  "Replace existing parameters (uncheck to append to existing ones)"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Close')),
        TextButton(
            onPressed: allSelectedArgs.isNotEmpty
                ? () {
                    Navigator.of(context).pop(ArgumentsPickerDialogResult(
                        allSelectedArgs,
                        replaceArgs: replaceArgs));
                  }
                : null,
            child: Text('Pick'))
      ],
    );
  }
}

class ArgumentsPickerDialogResult {
  final List<String> selectedArguments;
  bool replaceArgs = true;

  ArgumentsPickerDialogResult(this.selectedArguments,
      {this.replaceArgs = true});
}
