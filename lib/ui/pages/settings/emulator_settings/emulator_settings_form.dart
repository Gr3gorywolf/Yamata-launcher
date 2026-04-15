import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/app_selection_dialog.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/searchable_dropdown_form_field.dart';
import 'package:yamata_launcher/ui/widgets/wrapped_link_text.dart';
import 'package:yamata_launcher/utils/flatpak_utils.dart';

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
  List<String> availableFlatpaks = [];
  List<GameRunner> availableRunners = [];
  List<GameRunnerParam> availableParameters = [];
  GameRunner? selectedRunner;
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
      loadRunners();
      handleLookupRunner();
    } else if (availableConsoles.isNotEmpty) {
      selectedConsole = availableConsoles.first.slug ?? "";
    }
    if (Platform.isLinux) {
      fetchFlatpaks();
    }
    super.initState();
  }

  Future fetchFlatpaks() async {
    if (Platform.isLinux) {
      var flatpakSet = await FlatpakUtils.getInstalledFlatpakAppIds();
      setState(() {
        availableFlatpaks = flatpakSet.toList();
      });
    }
  }

  void handleLookupRunner() async {
    var runners = await EmulatorService.getAvailableRunners(selectedConsole);
    var binary = selectedBinaryController.text;
    GameRunner? matchedRunner;
    try {
      matchedRunner = runners.firstWhere(
        (runner) =>
            binary.contains(runner.executablePath) ||
            runner.executablePath.contains(binary),
      );
    } catch (e) {
      print("Error looking up runner: $e");
    }

    if (matchedRunner != null) {
      var params = await matchedRunner.getParams(selectedConsole, binary);
      setState(() {
        selectedRunner = matchedRunner;
        availableParameters = params;
      });
    }
  }

  void handleSelectEmulatorBinary() async {
    if (Platform.isAndroid) {
      var consoleEmulators =
          EmulatorService.getEmulatorPackagesForConsole(selectedConsole);
      var result = await AppSelectionDialog.show(context,
          filteredApps: consoleEmulators);
      if (result != null) {
        setState(() {
          selectedBinaryController.text = result?.packageName ?? "";
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
      handleLookupRunner();
    }
  }

  Future loadRunners() async {
    var runners = await EmulatorService.getAvailableRunners(selectedConsole);
    setState(() {
      availableRunners =
          runners.where((runner) => runner.isRunnerAvailable).toList();
    });
  }

  void handleChangeSelectedConsole(String? value) async {
    setState(() {
      selectedConsole = value ?? "";
    });
    await loadRunners();
    if (selectedBinaryController.text.isNotEmpty) {
      handleLookupRunner();
    }
  }

  void handlePickFlatpak() async {
    var options = availableFlatpaks
        .map((app) => PickerOption(label: app, value: app))
        .toList();
    var selectedOption =
        await AlertsService.showPicker(context, "Select a Flatpak", options);
    if (selectedOption != null) {
      setState(() {
        selectedBinaryController.text = selectedOption.value;
      });
    }
  }

  void handlePickParameters() async {
    if (selectedRunner == null) return;
    var options = availableParameters
        .map((param) => PickerOption(label: param.name, value: param.value))
        .toList();
    var selectedOption = await AlertsService.showPicker(
        context, "Append a launch parameter", options,
        showOptionValues: true);
    if (selectedOption != null) {
      launchParametersController.text += " " + selectedOption.value;
      launchParametersController.text = launchParametersController.text.trim();
      setState(() {});
    }
  }

  void handlePickGameRunner() async {
    var options = availableRunners
        .map((app) => PickerOption(label: app.name, value: app.executablePath))
        .toList();
    var selectedOption = await AlertsService.showPicker(
        context, "Select a Game Runner", options);
    if (selectedOption != null) {
      setState(() {
        selectedBinaryController.text = selectedOption.value;
      });
      handleLookupRunner();
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
                  onChanged: handleChangeSelectedConsole,
                ),
                additionalContent: [
                  if (selectedRunner != null)
                    WrappedLinkText(
                      text:
                          "The games will be launched using ${selectedRunner?.name} game runner",
                      linkText: "Learn more about game runners here",
                      link: "https://example.com/game-runners",
                    ),
                ],
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
                additionalContent: [
                  if (availableRunners.isNotEmpty ||
                      availableFlatpaks.isNotEmpty)
                    Row(
                      children: [
                        if (availableFlatpaks.isNotEmpty)
                          TextButton.icon(
                              onPressed: handlePickFlatpak,
                              label: Text("Pick a flatpak"),
                              icon: Icon(Icons.apps)),
                        if (availableRunners.isNotEmpty)
                          TextButton.icon(
                              onPressed: handlePickGameRunner,
                              label: Text("Pick a runner"),
                              icon: Icon(Icons.rocket_launch)),
                      ],
                    )
                ],
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
                    maxLines: 4,
                    minLines: 3,
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
                  additionalContent: availableParameters.isNotEmpty
                      ? [
                          TextButton.icon(
                              onPressed: handlePickParameters,
                              label: Text("${selectedRunner?.name} parameters"),
                              icon: Icon(Icons.code)),
                        ]
                      : null,
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
