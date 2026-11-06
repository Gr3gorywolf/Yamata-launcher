import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/runner_configuration.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/app_selection_dialog.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/flatpak_picker.dart';
import 'package:yamata_launcher/ui/widgets/hint_banner.dart';

/// The shared launch fields. Runner-specific controls intentionally remain in
/// their module and are displayed by this small shell.
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
  final RunnerConfiguration? runnerConfig;
  final bool enableBinaryEditing;
  final bool showLaunchParameters;
  final Future<void> Function(String value)? onBinaryChanged;
  final Future<void> Function(String value)? onLaunchParametersChanged;
  final ValueChanged<RunnerConfiguration?>? onRunnerConfigChanged;

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
    this.runnerConfig,
    this.enableBinaryEditing = true,
    this.showLaunchParameters = true,
    this.onBinaryChanged,
    this.onLaunchParametersChanged,
    this.onRunnerConfigChanged,
  });

  @override
  State<EmulatorLaunchSettingsFields> createState() =>
      _EmulatorLaunchSettingsFieldsState();
}

class _EmulatorLaunchSettingsFieldsState
    extends State<EmulatorLaunchSettingsFields> {
  List<GameRunner> _runners = [];
  String _lastBinaryValue = '';
  String _lastLaunchParametersValue = '';

  @override
  void initState() {
    super.initState();
    _lastBinaryValue = widget.binaryController.text;
    _lastLaunchParametersValue = widget.launchParametersController.text;
    widget.binaryController.addListener(_handleBinaryChanged);
    widget.launchParametersController
        .addListener(_handleLaunchParametersChanged);
    _loadRunners();
  }

  @override
  void didUpdateWidget(covariant EmulatorLaunchSettingsFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.console != widget.console) _loadRunners();
  }

  @override
  void dispose() {
    widget.binaryController.removeListener(_handleBinaryChanged);
    widget.launchParametersController
        .removeListener(_handleLaunchParametersChanged);
    super.dispose();
  }

  Future<void> _loadRunners() async {
    if (widget.console.trim().isEmpty) return;
    final runners = await EmulatorService.getCompatibleRunners(widget.console);
    if (!mounted) return;
    setState(() => _runners =
        runners.where((runner) => runner.isRunnerInstalled).toList());
  }

  void _handleBinaryChanged() {
    final value = widget.binaryController.text;
    if (value == _lastBinaryValue) return;
    _lastBinaryValue = value;
    widget.onBinaryChanged?.call(value);
  }

  void _handleLaunchParametersChanged() {
    final value = widget.launchParametersController.text;
    if (value == _lastLaunchParametersValue) return;
    _lastLaunchParametersValue = value;
    widget.onLaunchParametersChanged?.call(value);
  }

  GameRunner? get _configuredRunner {
    final config = widget.runnerConfig;
    return config == null
        ? null
        : EmulatorService.getRunnerById(config.runnerId);
  }

  Future<void> _chooseRunner() async {
    if (_runners.isEmpty) {
      AlertsService.showErrorSnackbar(
        'There are no installed runners available for this platform.',
        ctx: context,
      );
      return;
    }
    final runnerId = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _runners
              .map((item) => ListTile(
                    leading: const Icon(Icons.rocket_launch),
                    title: Text(item.name),
                    onTap: () => Navigator.pop(context, item.runnerId),
                  ))
              .toList(),
        ),
      ),
    );
    if (runnerId == null) return;
    final runner = EmulatorService.getRunnerById(runnerId);
    if (runner == null) return;

    await _configureRunner(
      runner,
      initialConfiguration: widget.runnerConfig?.runnerId == runner.runnerId
          ? widget.runnerConfig
          : null,
    );
  }

  Future<void> _configureCurrentRunner() async {
    final runner = _configuredRunner;
    final configuration = widget.runnerConfig;
    if (runner == null || configuration == null) return;
    await _configureRunner(runner, initialConfiguration: configuration);
  }

  Future<void> _configureRunner(
    GameRunner runner, {
    RunnerConfiguration? initialConfiguration,
  }) async {
    var updatedConfig =
        initialConfiguration ?? RunnerConfiguration(runnerId: runner.runnerId);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Configure ${runner.name}'),
        content: StatefulBuilder(
          builder: (context, setDialogState) =>
              runner.buildEmulatorSettingsConfiguration(
            console: widget.console,
            configuration: updatedConfig,
            onChanged: (configuration) =>
                setDialogState(() => updatedConfig = configuration),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.onRunnerConfigChanged?.call(updatedConfig);
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectEmulatorBinary() async {
    if (Platform.isAndroid) {
      final result = await AppSelectionDialog.show(
        context,
        filteredApps:
            EmulatorService.getEmulatorPackagesForConsole(widget.console),
      );
      if (result != null)
        widget.binaryController.text = result.packageName ?? '';
      return;
    }

    String? path;
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select emulator binary',
        type: FileType.custom,
        allowedExtensions: VALID_EXECUTABLE_EXTENSIONS,
        initialDirectory: Platform.isMacOS ? '/Applications' : null,
      );
      path = result?.files.single.path;
    } catch (_) {
      path = await FileSystemService.showFilePicker(
        allowedExtensions: VALID_EXECUTABLE_EXTENSIONS,
      );
    }
    if (path != null) widget.binaryController.text = path;
  }

  @override
  Widget build(BuildContext context) {
    final runner = _configuredRunner;
    final runnerConfigured = widget.runnerConfig != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (runnerConfigured) ...[
          HintBanner(
            text: runner == null
                ? 'A runner is configured but is no longer available.'
                : '${runner.name} is configured for this platform.',
            trailing: runner == null
                ? null
                : IconButton(
                    tooltip: 'Configure runner',
                    onPressed: _configureCurrentRunner,
                    icon: const Icon(Icons.settings),
                  ),
          ),
          _runnerActions(),
        ] else
          DialogSectionItem(
            title: widget.binaryTitle,
            icon: Icons.videogame_asset,
            helperText: widget.binaryHelperText,
            actions: [
              if (widget.enableBinaryEditing &&
                  widget.binaryController.text.isNotEmpty)
                IconButton(
                  onPressed: widget.binaryController.clear,
                  icon: const Icon(Icons.clear),
                ),
              if (widget.enableBinaryEditing)
                IconButton(
                  onPressed: _selectEmulatorBinary,
                  icon: const Icon(Icons.file_open),
                ),
            ],
            content: TextField(
              controller: widget.binaryController,
              enabled: widget.enableBinaryEditing,
              decoration: InputDecoration(
                hintText: widget.binaryHintText,
                filled: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            additionalContent: [
              if (Platform.isLinux)
                FlatpakPicker(
                  onSelected: (value) => widget.binaryController.text = value,
                ),
              _runnerActions(),
            ],
          ),
        if (widget.showLaunchParameters)
          DialogSectionItem(
            title: widget.launchParametersTitle,
            helperText: widget.launchParametersHelperText,
            icon: Icons.terminal,
            actions: const [],
            content: TextField(
              controller: widget.launchParametersController,
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                hintText: widget.launchParametersHintText,
                filled: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _runnerActions() {
    return Row(
      children: [
        Expanded(
          child: TextButton.icon(
            onPressed: _chooseRunner,
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Choose a runner'),
          ),
        ),
        if (widget.runnerConfig != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: TextButton.icon(
              onPressed: () => widget.onRunnerConfigChanged?.call(null),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              icon: const Icon(Icons.close),
              label: const Text('Unselect runner'),
            ),
          ),
        ],
      ],
    );
  }
}
