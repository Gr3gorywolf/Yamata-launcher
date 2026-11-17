import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/runner_configuration.dart';
import 'package:yamata_launcher/services/game-runners/wur_game_runner.dart';
import 'package:yamata_launcher/ui/pages/settings/game_runners_settings/runner_settings_page.dart';
import 'package:yamata_launcher/ui/widgets/wur/wur_configuration_form.dart';

class WurEmulatorSettings extends StatefulWidget {
  final WurGameRunner runner;
  final RunnerConfiguration configuration;
  final ValueChanged<RunnerConfiguration> onChanged;

  const WurEmulatorSettings({
    super.key,
    required this.runner,
    required this.configuration,
    required this.onChanged,
  });

  @override
  State<WurEmulatorSettings> createState() => _WurEmulatorSettingsState();
}

class _WurEmulatorSettingsState extends State<WurEmulatorSettings> {
  late Future<WurConfigurationOptions> _options;
  late String _container;
  late Map<String, dynamic> _overrides;

  Map<String, dynamic> _mapValue(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    final settings = widget.configuration.settings;
    _container = settings['container']?.toString() ?? '';
    final launch = _mapValue(settings['launch']);
    // Read the flat shape emitted by Yamata's initial WUR integration too.
    if (!launch.containsKey('fsr') && settings['fsr'] is bool) {
      launch['fsr'] = settings['fsr'];
    }
    if (!launch.containsKey('fsrSharpness') &&
        settings['fsrSharpness'] is num) {
      launch['fsrSharpness'] = settings['fsrSharpness'];
    }
    if (!launch.containsKey('environment') && settings['environment'] is Map) {
      launch['environment'] = settings['environment'];
    }
    _overrides = {
      'components': _mapValue(settings['components']),
      'launch': launch,
    };
    _options = widget.runner.loadConfigurationOptions();
  }

  void _emit() {
    widget.onChanged(RunnerConfiguration(
      runnerId: widget.configuration.runnerId,
      settings: {
        if (_container.isNotEmpty) 'container': _container,
        ..._overrides,
      },
    ));
  }

  Future<void> _manageContainers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RunnerSettings(runner: widget.runner),
      ),
    );
    if (!mounted) return;
    final future = widget.runner.loadConfigurationOptions();
    setState(() => _options = future);
    late WurConfigurationOptions options;
    try {
      options = await future;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    if (_container.isNotEmpty &&
        !options.containers.any((item) => item.name == _container)) {
      _container = '';
      _emit();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 620,
      child: FutureBuilder<WurConfigurationOptions>(
        future: _options,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              snapshot.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            );
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final options = snapshot.data!;
          final selectedContainer = options.containers
                  .any((container) => container.name == _container)
              ? _container
              : '';
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 680),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedContainer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Container',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Use the default container'),
                      ),
                      ...options.containers.map(
                        (container) => DropdownMenuItem(
                          value: container.name,
                          child: Text(container.isDefault
                              ? '${container.name} (default)'
                              : container.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _container = value ?? '');
                      _emit();
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _manageContainers,
                      icon: const Icon(Icons.settings),
                      label: const Text('Manage containers'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  WurConfigurationForm(
                    initialValue: _overrides,
                    options: options,
                    allowContainerFields: false,
                    onChanged: (value) {
                      _overrides = value;
                      _emit();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
