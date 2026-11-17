import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/app_selection_dialog.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/flatpak_picker.dart';

/// Common runner setup shell. Individual runners can supply additional
/// controls below the executable selector through [GameRunner.buildRunnerSettings].
class RunnerSettings extends StatefulWidget {
  final GameRunner runner;

  const RunnerSettings({super.key, required this.runner});

  @override
  State<RunnerSettings> createState() => _RunnerSettingsState();
}

class _RunnerSettingsState extends State<RunnerSettings> {
  late final TextEditingController _executableController;
  String _lastExecutablePath = '';

  @override
  void initState() {
    super.initState();
    _lastExecutablePath = widget.runner.executablePath;
    _executableController = TextEditingController(text: _lastExecutablePath);
    _executableController.addListener(_saveExecutablePath);
  }

  @override
  void dispose() {
    _executableController.removeListener(_saveExecutablePath);
    _executableController.dispose();
    super.dispose();
  }

  void _saveExecutablePath() {
    final path = _executableController.text;
    if (path == _lastExecutablePath) return;
    _lastExecutablePath = path;
    EmulatorService.setRunnerExecutablePath(widget.runner, path);
    setState(() {});
  }

  void _refresh() {
    final path = widget.runner.executablePath;
    if (_executableController.text != path) {
      _executableController.removeListener(_saveExecutablePath);
      _executableController.text = path;
      _lastExecutablePath = path;
      _executableController.addListener(_saveExecutablePath);
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectExecutable() async {
    if (Platform.isAndroid) {
      final app =
          await AppSelectionDialog.show(context, filteredApps: const []);
      if (app != null) _executableController.text = app.packageName ?? '';
      return;
    }

    String? path;
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select runner executable',
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
    if (path != null) _executableController.text = path;
  }

  @override
  Widget build(BuildContext context) {
    final runnerContent = widget.runner.buildRunnerSettings(
      context,
      onRefresh: _refresh,
    );
    final canEditPath = FileSystemService.isDesktop;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.runner.name} Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DialogSectionItem(
                title: 'Runner executable',
                icon: Icons.rocket_launch,
                helperText:
                    'Select the executable or application used to open ${widget.runner.name}.',
                actions: [
                  if (canEditPath && _executableController.text.isNotEmpty)
                    IconButton(
                      onPressed: _executableController.clear,
                      icon: const Icon(Icons.clear),
                    ),
                  IconButton(
                    onPressed: _selectExecutable,
                    icon: const Icon(Icons.file_open),
                  ),
                ],
                content: TextField(
                  controller: _executableController,
                  enabled: canEditPath,
                  decoration: const InputDecoration(
                    hintText: 'Runner executable path',
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                additionalContent: [
                  if (Platform.isLinux)
                    FlatpakPicker(
                      onSelected: (value) => _executableController.text = value,
                    ),
                ],
              ),
              if (runnerContent != null) ...[
                const SizedBox(height: 12),
                runnerContent,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
