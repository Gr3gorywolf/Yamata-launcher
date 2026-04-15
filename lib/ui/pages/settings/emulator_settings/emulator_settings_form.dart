import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/emulator_launch_settings_fields.dart';
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
  final launchParametersController = TextEditingController();
  final selectedBinaryController = TextEditingController();
  String selectedConsole = "";

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

  @override
  void dispose() {
    launchParametersController.dispose();
    selectedBinaryController.dispose();
    super.dispose();
  }

  void handleChangeSelectedConsole(String? value) {
    setState(() {
      selectedConsole = value ?? "";
    });
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
                  onChanged: handleChangeSelectedConsole,
                ),
              ),
              EmulatorLaunchSettingsFields(
                console: selectedConsole,
                binaryController: selectedBinaryController,
                launchParametersController: launchParametersController,
                binaryTitle: "Emulator $emulatorExecutableType",
                binaryHintText: "Emulator $emulatorExecutableType path",
                binaryHelperText:
                    "Select the emulator $emulatorExecutableType to be used for the selected console. ${FileSystemService.isDesktop ? " If no $emulatorExecutableType is selected will launch the game directly (Useful for desktop Games)" : ""}.",
                launchParametersTitle: "Launch parameters",
                launchParametersHintText: "Custom launch parameters",
                launchParametersHelperText:
                    "Parameters flags used when launching the ROM (if supported by the emulator)",
                enableBinaryEditing: FileSystemService.isDesktop,
                showLaunchParameters: FileSystemService.isDesktop,
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
