import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/custom_download_path.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/searchable_dropdown_form_field.dart';

class CustomPathsForm extends StatefulWidget {
  final List<String> existingConsoles;
  final CustomDownloadPath? editingPath;
  const CustomPathsForm(
      {super.key, required this.existingConsoles, this.editingPath});

  @override
  State<CustomPathsForm> createState() => _CustomPathsFormState();
}

class _CustomPathsFormState extends State<CustomPathsForm> {
  List<Console> availableConsoles = [];
  String selectedConsole = "";
  String selectedPath = "";
  @override
  void initState() {
    availableConsoles = ConsoleService.getConsoles(includeUnsupported: true)
        .where((console) => !widget.existingConsoles.contains(console.slug))
        .toList();
    if (widget.editingPath != null) {
      selectedConsole = widget.editingPath!.console;
      selectedPath = widget.editingPath!.folderPath;
    } else if (availableConsoles.isNotEmpty) {
      selectedConsole = availableConsoles.first.slug ?? "";
    }

    print(selectedConsole);
    super.initState();
  }

  void handleSave() {
    if (selectedConsole.isEmpty || selectedPath.isEmpty) {
      AlertsService.showErrorSnackbar("Please select a console and folder path",
          ctx: context);
      return;
    }
    CustomDownloadPath path = CustomDownloadPath(
      console: selectedConsole,
      folderPath: selectedPath,
    );
    Navigator.of(context).pop(path);
  }

  void handleSelectPath() async {
    final selectedDirectory = await FileSystemService.showFolderPicker();

    if (selectedDirectory == null) return;
    var isValidDirectory =
        await FileSystemService.testDirectory(selectedDirectory);
    if (isValidDirectory) {
      setState(() {
        selectedPath = selectedDirectory;
      });
    } else {
      AlertsService.showErrorSnackbar(
          "The selected path is not a valid directory.",
          ctx: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          '${widget.editingPath == null ? "Add" : "Edit"} Custom Download Path'),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      contentPadding: const EdgeInsets.all(15.0),
      content: Container(
        constraints: BoxConstraints(
          minWidth: 300,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DialogSectionItem(
              title: "Console",
              icon: Icons.gamepad,
              actions: [],
              content: SearchableDropdownFormField<String>(
                enabled: widget.editingPath == null,
                value: selectedConsole.isNotEmpty ? selectedConsole : null,
                items: availableConsoles
                    .map((console) => DropdownMenuItem<String>(
                          value: console.slug ?? "",
                          child: Text(console.name ?? ""),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedConsole = value ?? "";
                  });
                },
              ),
            ),
            DialogSectionItem(
              title: "Folder Path",
              icon: Icons.folder,
              helperText:
                  "Select the folder path to be used for the selected console.",
              actions: [
                if (selectedPath.isNotEmpty)
                  IconButton(
                      onPressed: () {
                        setState(() {
                          selectedPath = "";
                        });
                      },
                      icon: Icon(Icons.clear)),
                IconButton(
                    onPressed: handleSelectPath, icon: Icon(Icons.file_open))
              ],
              content: Text(selectedPath),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: handleSave,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
