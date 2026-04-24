import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/argument_group.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/app_selection_dialog.dart';
import 'package:yamata_launcher/ui/widgets/arguments_picker_dialog.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/wrapped_link_text.dart';
import 'package:yamata_launcher/utils/flatpak_utils.dart';

class EmulatorLaunchSettingsFields extends StatefulWidget {
  final String console;
  final TextEditingController binaryController;
  final TextEditingController launchParametersController;
  final String binaryTitle;
  final String binaryHintText;
  final String? binaryHelperText;
  final String launchParametersTitle;
  final String launchParametersHintText;
  final String? launchParametersHelperText;
  final EmulatorSetting? emulatorSetting;
  final bool enableBinaryEditing;
  final bool showLaunchParameters;
  final Future<void> Function(String value)? onBinaryChanged;
  final Future<void> Function(String value)? onLaunchParametersChanged;

  const EmulatorLaunchSettingsFields({
    super.key,
    required this.console,
    required this.binaryController,
    required this.launchParametersController,
    required this.binaryTitle,
    required this.binaryHintText,
    required this.launchParametersTitle,
    required this.launchParametersHintText,
    this.binaryHelperText,
    this.launchParametersHelperText,
    this.emulatorSetting,
    this.enableBinaryEditing = true,
    this.showLaunchParameters = true,
    this.onBinaryChanged,
    this.onLaunchParametersChanged,
  });

  @override
  State<EmulatorLaunchSettingsFields> createState() =>
      _EmulatorLaunchSettingsFieldsState();
}

class _EmulatorLaunchSettingsFieldsState
    extends State<EmulatorLaunchSettingsFields> {
  List<String> availableFlatpaks = [];
  List<GameRunner> consoleRunners = [];
  List<GameRunner> availableRunners = [];
  List<ArgumentGroup> availableParameters = [];
  GameRunner? selectedRunner;
  String _lastBinaryValue = '';
  String _lastLaunchParametersValue = '';
  int _lookupVersion = 0;

  @override
  void initState() {
    super.initState();
    _lastBinaryValue = widget.binaryController.text;
    _lastLaunchParametersValue = widget.launchParametersController.text;
    widget.binaryController.addListener(_handleBinaryControllerChanged);
    widget.launchParametersController
        .addListener(_handleLaunchParametersControllerChanged);
    _initialize();
  }

  @override
  void didUpdateWidget(covariant EmulatorLaunchSettingsFields oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.binaryController != widget.binaryController) {
      oldWidget.binaryController.removeListener(_handleBinaryControllerChanged);
      _lastBinaryValue = widget.binaryController.text;
      widget.binaryController.addListener(_handleBinaryControllerChanged);
    }

    if (oldWidget.launchParametersController !=
        widget.launchParametersController) {
      oldWidget.launchParametersController
          .removeListener(_handleLaunchParametersControllerChanged);
      _lastLaunchParametersValue = widget.launchParametersController.text;
      widget.launchParametersController
          .addListener(_handleLaunchParametersControllerChanged);
    }

    if (oldWidget.console != widget.console ||
        oldWidget.emulatorSetting?.console != widget.emulatorSetting?.console ||
        oldWidget.emulatorSetting?.emulatorBinary !=
            widget.emulatorSetting?.emulatorBinary) {
      _refreshAvailableOptions();
    }
  }

  @override
  void dispose() {
    widget.binaryController.removeListener(_handleBinaryControllerChanged);
    widget.launchParametersController
        .removeListener(_handleLaunchParametersControllerChanged);
    super.dispose();
  }

  Future<void> _initialize() async {
    await _fetchFlatpaks();
    await _refreshAvailableOptions();
  }

  Future<void> _fetchFlatpaks() async {
    if (!Platform.isLinux) {
      return;
    }

    final flatpakSet = await FlatpakUtils.getInstalledFlatpakAppIds();
    if (!mounted) {
      return;
    }

    setState(() {
      availableFlatpaks = flatpakSet.toList()..sort();
    });
  }

  Future<void> _refreshAvailableOptions() async {
    final console = widget.console.trim();
    final runners = console.isEmpty
        ? <GameRunner>[]
        : await EmulatorService.getCompatibleRunners(console);
    final filteredRunners =
        runners.where((runner) => runner.isRunnerInstalled).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      availableRunners = filteredRunners;
      consoleRunners = runners;
    });

    await _lookupRunner(widget.binaryController.text);
  }

  Future<void> _lookupRunner(String binary) async {
    final lookupVersion = ++_lookupVersion;
    final normalizedBinary = binary.trim();
    final fallbackBinary = _getFallbackBinary();
    final effectiveBinary =
        normalizedBinary.isNotEmpty ? normalizedBinary : fallbackBinary;
    final availableRunnerList = consoleRunners;

    if (effectiveBinary.isEmpty || widget.console.trim().isEmpty) {
      if (!mounted || lookupVersion != _lookupVersion) {
        return;
      }
      setState(() {
        selectedRunner = null;
        availableParameters = [];
      });
      return;
    }

    GameRunner? matchedRunner;
    for (final runner in availableRunnerList) {
      if (runner.executablePath.isEmpty) {
        continue;
      }
      if (effectiveBinary.contains(runner.executablePath) ||
          runner.executablePath.contains(effectiveBinary)) {
        matchedRunner = runner;
        break;
      }
    }

    if (matchedRunner == null) {
      if (!mounted || lookupVersion != _lookupVersion) {
        return;
      }
      setState(() {
        selectedRunner = null;
        availableParameters = [];
      });
      return;
    }

    final params = await matchedRunner.getAvailableParams(
        widget.console.trim(), effectiveBinary);
    if (!mounted || lookupVersion != _lookupVersion) {
      return;
    }

    setState(() {
      selectedRunner = matchedRunner;
      availableParameters = params;
    });
  }

  String _getFallbackBinary() {
    final setting = widget.emulatorSetting;
    if (setting == null || setting.console != widget.console) {
      return '';
    }
    return setting.emulatorBinary.trim();
  }

  void _handleBinaryControllerChanged() {
    final binary = widget.binaryController.text;
    if (binary == _lastBinaryValue) {
      return;
    }

    _lastBinaryValue = binary;
    widget.onBinaryChanged?.call(binary);
    _lookupRunner(binary);
  }

  void _handleLaunchParametersControllerChanged() {
    final launchParameters = widget.launchParametersController.text;
    if (launchParameters == _lastLaunchParametersValue) {
      return;
    }

    _lastLaunchParametersValue = launchParameters;
    widget.onLaunchParametersChanged?.call(launchParameters);
  }

  Future<void> _handleSelectEmulatorBinary() async {
    if (Platform.isAndroid) {
      final consoleEmulators =
          EmulatorService.getEmulatorPackagesForConsole(widget.console);
      final result = await AppSelectionDialog.show(
        context,
        filteredApps: consoleEmulators,
      );
      if (result == null) {
        return;
      }

      widget.binaryController.text = result.packageName ?? '';
      return;
    }

    final validExtensions = VALID_EXECUTABLE_EXTENSIONS;
    String? selectedFilePath;
    try {
      final selectedFile = await FilePicker.platform.pickFiles(
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
      final filePath = await FileSystemService.showFilePicker(
        allowedExtensions: validExtensions,
      );
      if (filePath != null) {
        selectedFilePath = filePath;
      }
    }

    if (selectedFilePath == null) {
      return;
    }

    widget.binaryController.text = selectedFilePath;
  }

  Future<void> _handlePickFlatpak() async {
    final options = availableFlatpaks
        .map((app) => PickerOption(label: app, value: app))
        .toList();
    final selectedOption =
        await AlertsService.showPicker(context, "Select a Flatpak", options);
    if (selectedOption == null) {
      return;
    }

    widget.binaryController.text = selectedOption.value;
  }

  Future<void> _handlePickGameRunner() async {
    final options = availableRunners
        .map((runner) =>
            PickerOption(label: runner.name, value: runner.executablePath))
        .toList();
    final selectedOption = await AlertsService.showPicker(
        context, "Select a Game Runner", options);
    if (selectedOption == null) {
      return;
    }

    widget.binaryController.text = selectedOption.value;
  }

  Future<void> _handlePickParameters() async {
    if (selectedRunner == null) {
      return;
    }
    final selectedOption = await ArgumentsPickerDialog.show(
      context,
      argumentGroups: availableParameters,
      title: "Pick ${selectedRunner?.name} Parameters",
    );
    if (selectedOption.selectedArguments.isEmpty) {
      return;
    }

    final existingValue = widget.launchParametersController.text.trim();
    final appendedValue = [
      if (existingValue.isNotEmpty && !selectedOption.replaceArgs)
        existingValue,
      ...selectedOption.selectedArguments,
    ].join(' ');
    widget.launchParametersController.text = appendedValue;
  }

  void _clearBinarySelection() {
    widget.binaryController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final binaryAdditionalContent = <Widget>[
      if (availableRunners.isNotEmpty || availableFlatpaks.isNotEmpty)
        Row(
          children: [
            if (availableFlatpaks.isNotEmpty)
              TextButton.icon(
                onPressed: _handlePickFlatpak,
                label: Text("Pick a flatpak"),
                icon: Icon(Icons.apps),
              ),
            if (availableRunners.isNotEmpty)
              TextButton.icon(
                onPressed: _handlePickGameRunner,
                label: Text("Pick a runner"),
                icon: Icon(Icons.rocket_launch),
              ),
          ],
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedRunner != null) ...[
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: WrappedLinkText(
              text:
                  "The games will be launched using ${selectedRunner?.name} game runner",
              linkText: "Learn more about game runners here",
              link: AppConstants.gameRunnersGuideEntry,
            ),
          ),
          SizedBox(height: 5),
        ],
        DialogSectionItem(
          title: widget.binaryTitle,
          icon: Icons.videogame_asset,
          helperText: widget.binaryHelperText,
          actions: [
            if (widget.binaryController.text.isNotEmpty)
              IconButton(
                onPressed: _clearBinarySelection,
                icon: Icon(Icons.clear),
              ),
            IconButton(
              onPressed: _handleSelectEmulatorBinary,
              icon: Icon(Icons.file_open),
            ),
          ],
          content: TextField(
            controller: widget.binaryController,
            enabled: widget.enableBinaryEditing,
            decoration: InputDecoration(
              hintText: widget.binaryHintText,
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
          ),
          additionalContent: binaryAdditionalContent.isNotEmpty
              ? binaryAdditionalContent
              : null,
        ),
        if (widget.showLaunchParameters)
          DialogSectionItem(
            title: widget.launchParametersTitle,
            helperText: widget.launchParametersHelperText,
            icon: Icons.terminal,
            actions: [],
            content: TextField(
              controller: widget.launchParametersController,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText: widget.launchParametersHintText,
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
            ),
            additionalContent: availableParameters.isNotEmpty
                ? [
                    TextButton.icon(
                      onPressed: _handlePickParameters,
                      label: Text("${selectedRunner?.name} parameters"),
                      icon: Icon(Icons.code),
                    ),
                  ]
                : null,
          ),
      ],
    );
  }
}
