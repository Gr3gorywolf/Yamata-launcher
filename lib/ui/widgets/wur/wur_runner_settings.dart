import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/game-runners/wur_game_runner.dart';
import 'package:yamata_launcher/ui/widgets/wur/wur_configuration_form.dart';

enum _ContainerAction { edit, makeDefault, delete }

class WurRunnerSettings extends StatefulWidget {
  final WurGameRunner runner;
  final VoidCallback? onRefresh;

  const WurRunnerSettings({
    super.key,
    required this.runner,
    this.onRefresh,
  });

  @override
  State<WurRunnerSettings> createState() => _WurRunnerSettingsState();
}

class _WurRunnerSettingsState extends State<WurRunnerSettings> {
  List<WurContainer> _containers = const [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.runner.executablePath.isNotEmpty) _reload();
  }

  Future<void> _reload() async {
    if (widget.runner.executablePath.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final containers = await widget.runner.listContainers();
      if (!mounted) return;
      setState(() => _containers = containers);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runTask(
    String title,
    String message,
    Future<void> Function(ValueNotifier<String> status) action,
  ) async {
    final status = ValueNotifier<String>(message);
    final loading = AlertsService.showLoadingAlert(
      context,
      title,
      message,
      textNotifier: status,
    );
    try {
      await action(status);
      loading.close();
      await _reload();
      widget.onRefresh?.call();
    } catch (error) {
      loading.close();
      if (!mounted) return;
      AlertsService.showErrorSnackbar(
        'WUR operation failed',
        ctx: context,
        exception: Exception(error.toString()),
      );
    } finally {
      status.dispose();
    }
  }

  Future<void> _install() async {
    await _runTask('Installing WUR', 'Downloading and installing WUR...',
        (status) async {
      final path = await widget.runner.install();
      status.value = 'Saving the WUR executable path...';
      await EmulatorService.setRunnerExecutablePath(widget.runner, path);
    });
  }

  Future<void> _setupDefaultContainer() async {
    await _runTask(
      'Setting up WUR',
      'Downloading and installing the recommended runtime and components...',
      (status) async {
        await widget.runner.runCommandWithStatus(
          ['install-recommended'],
          (message) => status.value = message,
        );
        status.value = 'Creating and initializing the default container...';
        await widget.runner.runCommandWithStatus(
          ['container', 'create', '--name', 'default'],
          (message) => status.value = message,
        );
      },
    );
  }

  Future<void> _addContainer() async {
    final name = await AlertsService.showPrompt(
      context,
      'Add WUR container',
      message: 'Enter a unique container name.',
      inputPlaceholder: 'Container name',
    );
    if (name == null || name.trim().isEmpty) return;
    await _runTask(
      'Creating container',
      'Creating and initializing ${name.trim()}...',
      (status) => widget.runner.runCommandWithStatus(
        ['container', 'create', '--name', name.trim()],
        (message) => status.value = message,
      ),
    );
  }

  Future<void> _makeDefault(WurContainer container) async {
    await _runTask(
      'Updating WUR',
      'Setting ${container.name} as the default container...',
      (_) => widget.runner.runCommand([
        'container',
        'default',
        '--name',
        container.name,
      ]).then((_) {}),
    );
  }

  Future<void> _delete(WurContainer container) async {
    if (_containers.length <= 1) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete WUR container'),
        content: Text(
          'Delete "${container.name}" and its Wine prefix? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runTask(
      'Deleting container',
      'Deleting ${container.name}...',
      (_) => widget.runner.runCommand([
        'container',
        'remove',
        '--name',
        container.name,
      ]).then((_) {}),
    );
  }

  Future<void> _editContainer(WurContainer container) async {
    try {
      final raw = await widget.runner.runJson([
        'container',
        'show',
        '--name',
        container.name,
      ]);
      if (raw is! Map) throw const FormatException('Invalid container JSON.');
      final containerJson = Map<String, dynamic>.from(raw);
      final options =
          await widget.runner.loadConfigurationOptions(includeRuntimes: true);
      var edited = <String, dynamic>{
        'runtime': containerJson['runtime'],
        'architecture': containerJson['architecture'],
        'components': containerJson['components'],
        'launch': containerJson['launch'],
      };
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${container.name} container settings'),
          content: SizedBox(
            width: 700,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 680),
              child: SingleChildScrollView(
                child: WurConfigurationForm(
                  initialValue: edited,
                  options: options,
                  allowContainerFields: true,
                  onChanged: (value) => edited = value,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (saved == true) {
        containerJson
          ..['runtime'] = edited['runtime']
          ..['architecture'] = edited['architecture']
          ..['components'] = edited['components']
          ..['launch'] = edited['launch']
          ..['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        final file =
            File(p.join(p.dirname(container.prefix), 'container.json'));
        final contents =
            const JsonEncoder.withIndent('  ').convert(containerJson);
        await file.writeAsString('$contents\n', flush: true);
        await _reload();
      }
    } catch (error) {
      if (!mounted) return;
      AlertsService.showErrorSnackbar(
        'Could not edit the container',
        ctx: context,
        exception: Exception(error.toString()),
      );
    }
  }

  void _handleAction(_ContainerAction action, WurContainer container) {
    switch (action) {
      case _ContainerAction.edit:
        _editContainer(container);
      case _ContainerAction.makeDefault:
        _makeDefault(container);
      case _ContainerAction.delete:
        _delete(container);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.runner.executablePath.isEmpty) {
      return Center(
        child: FilledButton.icon(
          onPressed: _install,
          icon: const Icon(Icons.download),
          label: const Text('Install WUR'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Containers',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            FilledButton.icon(
              onPressed: _loading
                  ? null
                  : (_containers.isEmpty
                      ? _setupDefaultContainer
                      : _addContainer),
              icon: Icon(_containers.isEmpty ? Icons.auto_fix_high : Icons.add),
              label: Text(
                _containers.isEmpty
                    ? 'Setup default container'
                    : 'Add new container',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Center(
              child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ))
        else if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error))
        else
          ..._containers.map(
            (container) => Card(
              child: ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(container.name),
                subtitle: Text(container.runtime),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (container.isDefault) const Chip(label: Text('Default')),
                    PopupMenuButton<_ContainerAction>(
                      onSelected: (action) => _handleAction(action, container),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _ContainerAction.edit,
                          child: Text('Edit container.json'),
                        ),
                        PopupMenuItem(
                          value: _ContainerAction.makeDefault,
                          enabled: !container.isDefault,
                          child: const Text('Set as default'),
                        ),
                        PopupMenuItem(
                          value: _ContainerAction.delete,
                          enabled: _containers.length > 1,
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
