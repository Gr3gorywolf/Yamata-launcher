import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/app_selection_dialog.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/searchable_dropdown_form_field.dart';

class EmulatorSettingsForm extends StatefulWidget {
  final List<String> existingConsoles;
  final Function(EmulatorSetting) onSubmit;
  final EmulatorSetting? editingSetting;
  const EmulatorSettingsForm(
      {super.key,
      required this.existingConsoles,
      required this.onSubmit,
      this.editingSetting});

  @override
  State<EmulatorSettingsForm> createState() => _EmulatorSettingsFormState();
}

class _EmulatorSettingsFormState extends State<EmulatorSettingsForm> {
  List<Console> availableConsoles = [];
  var launchParametersController = TextEditingController();
  var selectedBinaryController = TextEditingController();
  String selectedConsole = "";
  String selectedBinary = "";
  @override
  void initState() {
    availableConsoles = ConsoleService.getConsoles(includeUnsupported: true)
        .where((console) => !widget.existingConsoles.contains(console.slug))
        .toList();
    if (widget.editingSetting != null) {
      selectedConsole = widget.editingSetting!.console;
      selectedBinaryController.text = widget.editingSetting!.emulatorBinary;
      launchParametersController.text = widget.editingSetting!.launchParams;
    } else if (availableConsoles.isNotEmpty) {
      selectedConsole = availableConsoles.first.slug ?? "";
    }

    super.initState();
  }

  void handleSelectEmulatorBinary() async {
    if (Platform.isAndroid) {
      var consoleEmulators =
          EmulatorService.getEmulatorPackagesForConsole(selectedConsole);
      var result = await AppSelectionDialog.show(context,
          filteredApps: consoleEmulators);
      if (result != null) {
        setState(() {
          selectedBinaryController.text = result.packageName;
        });
      }
      return;
    }
    var validExtensions = VALID_EXECUTABLE_EXTENSIONS;
    String? selectedFilePath = null;
    try {
      FilePickerResult? selectedFile = await FilePicker.platform.pickFiles(
        dialogTitle: "Select Emulator Binary",
        type: FileType.custom,
        initialDirectory: Platform.isMacOS ? "/Applications" : null,
        allowedExtensions: validExtensions,
      );
      if (selectedFile != null) {
        selectedFilePath = selectedFile.files.single.path ?? "";
      }
    } catch (e) {
      print("Error selecting emulator binary: $e");
      var filePath = await FileSystemService.showFilePicker(
          allowedExtensions: validExtensions);
      if (filePath != null) {
        selectedFilePath = filePath;
      }
    }
    if (selectedFilePath != null) {
      setState(() {
        selectedBinaryController.text = selectedFilePath!;
      });
    }
  }

  void handleSave() {
    if (selectedConsole.isEmpty ||
        (selectedBinaryController.text.isEmpty &&
            !FileSystemService.isDesktop)) {
      AlertsService.showErrorSnackbar(
          "Please select a console and emulator binary path",
          ctx: context);
      return;
    }
    EmulatorSetting setting = EmulatorSetting(
      console: selectedConsole,
      emulatorBinary: selectedBinaryController.text,
      launchParams: launchParametersController.text,
    );
    widget.onSubmit(setting);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    var emulatorExecutableType =
        Platform.isAndroid || Platform.isMacOS ? "application" : "binary";
    return AlertDialog(
      title: Text(
          '${widget.editingSetting == null ? "Add" : "Edit"} Emulator Setting'),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      contentPadding: const EdgeInsets.all(15.0),
      content: Container(
        constraints: BoxConstraints(
          minWidth: 300,
          maxWidth: 400,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DialogSectionItem(
                title: "Console",
                icon: Icons.gamepad,
                actions: [],
                content: SearchableDropdownFormField<String>(
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
                title: "Emulator $emulatorExecutableType",
                icon: Icons.videogame_asset,
                helperText:
                    "Select the emulator $emulatorExecutableType to be used for the selected console. ${FileSystemService.isDesktop ? " If no $emulatorExecutableType is selected will launch the game directly (Useful for desktop Games)" : ""}.",
                actions: [
                  if (selectedBinaryController.text.isNotEmpty)
                    IconButton(
                        onPressed: () {
                          setState(() {
                            selectedBinaryController.text = "";
                          });
                        },
                        icon: Icon(Icons.clear)),
                  IconButton(
                      onPressed: handleSelectEmulatorBinary,
                      icon: Icon(Icons.file_open))
                ],
                content: TextField(
                  controller: selectedBinaryController,
                  enabled: FileSystemService.isDesktop,
                  decoration: InputDecoration(
                    hintText: "Emulator $emulatorExecutableType path",
                    helperMaxLines: 3,
                    helperStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (text) {
                    setState(() {});
                  },
                ),
              ),
              if (FileSystemService.isDesktop)
                DialogSectionItem(
                  title: "Launch parameters",
                  helperText:
                      "Parameters flags used when launching the ROM (if supported by the emulator)",
                  icon: Icons.terminal,
                  actions: [],
                  content: TextField(
                    controller: launchParametersController,
                    decoration: InputDecoration(
                      hintText: "Custom launch parameters",
                      helperMaxLines: 3,
                      helperStyle: TextStyle(color: Colors.grey[500]),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (text) {
                      setState(() {});
                    },
                  ),
                ),
            ],
          ),
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
