import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yamata_launcher/services/game-runners/wur_game_runner.dart';

class _EnvironmentEntry {
  String key;
  String value;

  _EnvironmentEntry(this.key, this.value);
}

/// The editable part shared by WUR container files and per-game overrides.
///
/// Container identity and filesystem metadata deliberately live outside this
/// widget. Per-game overrides deliberately omit runtime and architecture,
/// because WUR's game override schema does not accept either field.
class WurConfigurationForm extends StatefulWidget {
  final Map<String, dynamic> initialValue;
  final WurConfigurationOptions options;
  final bool allowContainerFields;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const WurConfigurationForm({
    super.key,
    required this.initialValue,
    required this.options,
    required this.allowContainerFields,
    required this.onChanged,
  });

  @override
  State<WurConfigurationForm> createState() => _WurConfigurationFormState();
}

class _WurConfigurationFormState extends State<WurConfigurationForm> {
  static const _launchBooleanLabels = <String, String>{
    'enableEsync': 'Enable Esync',
    'enableFsync': 'Enable Fsync',
    'enableMsync': 'Enable Msync',
    'enableWayland': 'Enable Wayland',
    'enableHdr': 'Enable HDR',
    'enableWow64': 'Enable WoW64',
    'showFps': 'Show FPS',
    'fsr': 'Enable FSR',
    'verboseLogs': 'Verbose logs',
  };

  late String _runtimeSource;
  late String _runtimeVersion;
  late String _architecture;
  late Map<String, Map<String, dynamic>> _components;
  late Map<String, bool> _launchBooleans;
  late Set<String> _componentEnabledOverrides;
  late Set<String> _componentVersionOverrides;
  late Set<String> _launchOverrides;
  late bool _frameRateOverride;
  late bool _environmentOverride;
  late double _fsrSharpness;
  late List<_EnvironmentEntry> _environment;
  late final TextEditingController _frameRateController;

  Map<String, dynamic> _mapValue(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    final runtime = _mapValue(widget.initialValue['runtime']);
    _runtimeSource = runtime['source']?.toString() ??
        (Platform.isMacOS ? 'wine-crossover' : 'ge-proton');
    _runtimeVersion = runtime['version']?.toString() ?? 'latest';
    _architecture = widget.initialValue['architecture']?.toString() ?? 'win64';

    final rawComponents = _mapValue(widget.initialValue['components']);
    _components = {};
    _componentEnabledOverrides = {};
    _componentVersionOverrides = {};
    for (final key in WurGameRunner.componentKeys.keys) {
      final raw = rawComponents[key];
      if (raw is Map) {
        final selection = Map<String, dynamic>.from(raw);
        if (selection.containsKey('enabled')) {
          _componentEnabledOverrides.add(key);
        }
        if (selection.containsKey('version')) {
          _componentVersionOverrides.add(key);
        }
        _components[key] = {
          'enabled': selection['enabled'] == true,
          'version': selection['version']?.toString() ?? 'latest',
        };
      } else {
        // Backward compatibility with Yamata's first WUR implementation,
        // where a component value was only its version string.
        _components[key] = {
          'enabled': raw != null,
          'version': raw?.toString() ?? 'latest',
        };
        if (raw != null) _componentVersionOverrides.add(key);
      }
    }

    final launch = _mapValue(widget.initialValue['launch']);
    _launchBooleans = {
      'enableEsync':
          launch['enableEsync'] is bool ? launch['enableEsync'] as bool : true,
      'enableFsync': launch['enableFsync'] is bool
          ? launch['enableFsync'] as bool
          : !Platform.isMacOS,
      'enableMsync': launch['enableMsync'] is bool
          ? launch['enableMsync'] as bool
          : Platform.isMacOS,
      'enableWayland': launch['enableWayland'] == true,
      'enableHdr': launch['enableHdr'] == true,
      'enableWow64': launch['enableWow64'] == true,
      'showFps': launch['showFps'] == true,
      'fsr': launch['fsr'] == true,
      'verboseLogs': launch['verboseLogs'] == true,
    };
    _launchOverrides = {
      for (final key in _launchBooleanLabels.keys)
        if (launch.containsKey(key)) key,
      if (launch.containsKey('fsrSharpness')) 'fsrSharpness',
    };
    _frameRateOverride = launch.containsKey('dxvkFrameRate');
    _environmentOverride = launch.containsKey('environment');
    _fsrSharpness =
        ((launch['fsrSharpness'] as num?) ?? 2).toDouble().clamp(1, 5);
    _frameRateController = TextEditingController(
      text: launch['dxvkFrameRate']?.toString() ?? '',
    );
    _environment = [];
    final environment = _mapValue(launch['environment']);
    for (final entry in environment.entries) {
      _environment.add(
        _EnvironmentEntry(entry.key, entry.value?.toString() ?? ''),
      );
    }
  }

  @override
  void dispose() {
    _frameRateController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _value() {
    final environment = <String, String>{};
    for (final entry in _environment) {
      final key = entry.key.trim();
      if (key.isNotEmpty) environment[key] = entry.value;
    }
    final frameRate = double.tryParse(_frameRateController.text.trim());
    final components = <String, dynamic>{};
    for (final entry in _components.entries) {
      final selection = <String, dynamic>{
        if (widget.allowContainerFields ||
            _componentEnabledOverrides.contains(entry.key))
          'enabled': entry.value['enabled'],
        if (widget.allowContainerFields ||
            _componentVersionOverrides.contains(entry.key))
          'version': entry.value['version'],
      };
      if (selection.isNotEmpty) components[entry.key] = selection;
    }
    final launch = <String, dynamic>{
      for (final entry in _launchBooleans.entries)
        if (widget.allowContainerFields || _launchOverrides.contains(entry.key))
          entry.key: entry.value,
      if (widget.allowContainerFields || _frameRateOverride)
        'dxvkFrameRate': frameRate,
      if (widget.allowContainerFields ||
          _launchOverrides.contains('fsrSharpness'))
        'fsrSharpness': _fsrSharpness.round(),
      if (widget.allowContainerFields || _environmentOverride)
        'environment': environment,
    };
    return {
      if (widget.allowContainerFields) ...{
        'runtime': {
          'source': _runtimeSource,
          'version': _runtimeVersion,
        },
        'architecture': _architecture,
      },
      if (widget.allowContainerFields || components.isNotEmpty)
        'components': components,
      if (widget.allowContainerFields || launch.isNotEmpty) 'launch': launch,
    };
  }

  void _update(VoidCallback update) {
    setState(update);
    widget.onChanged(_value());
  }

  List<String> _versionsForComponent(String key) => <String>{
        'latest',
        ...?widget.options.componentVersions[key],
        _components[key]!['version'].toString(),
      }.toList();

  List<String> get _runtimeSources {
    final sources = <String>{
      ...WurGameRunner.compatibleRuntimeSources,
      _runtimeSource,
    }.toList();
    return sources;
  }

  List<String> get _runtimeVersions => <String>{
        'latest',
        ...?widget.options.runtimeVersions[_runtimeSource],
        _runtimeVersion,
      }.toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.allowContainerFields) ...[
          Text('Runtime', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _runtimeSource,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    border: OutlineInputBorder(),
                  ),
                  items: _runtimeSources
                      .map((source) => DropdownMenuItem(
                            value: source,
                            child: Text(
                              WurGameRunner.runtimeSourceLabels[source] ??
                                  source,
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _update(() {
                      _runtimeSource = value;
                      _runtimeVersion = 'latest';
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _runtimeVersion,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Version',
                    border: OutlineInputBorder(),
                  ),
                  items: _runtimeVersions
                      .map((version) => DropdownMenuItem(
                            value: version,
                            child: Text(version),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _update(() => _runtimeVersion = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _architecture,
            decoration: const InputDecoration(
              labelText: 'Architecture',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'win32', child: Text('Win32')),
              DropdownMenuItem(value: 'win64', child: Text('Win64')),
              DropdownMenuItem(value: 'wow64', child: Text('WoW64')),
            ],
            onChanged: (value) {
              if (value != null) _update(() => _architecture = value);
            },
          ),
          const SizedBox(height: 24),
        ],
        Text('Components', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...WurGameRunner.componentKeys.entries.map((component) {
          final selection = _components[component.key]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(component.value),
                    subtitle: widget.allowContainerFields
                        ? null
                        : Text(
                            _componentEnabledOverrides.contains(component.key)
                                ? 'Enabled override'
                                : 'Uses container setting'),
                    secondary: !widget.allowContainerFields &&
                            _componentEnabledOverrides.contains(component.key)
                        ? IconButton(
                            tooltip: 'Use container setting',
                            onPressed: () => _update(() =>
                                _componentEnabledOverrides
                                    .remove(component.key)),
                            icon: const Icon(Icons.undo),
                          )
                        : null,
                    value: selection['enabled'] == true,
                    onChanged: (value) => _update(() {
                      selection['enabled'] = value;
                      _componentEnabledOverrides.add(component.key);
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selection['version'].toString(),
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Version',
                      border: const OutlineInputBorder(),
                      helperText: !widget.allowContainerFields &&
                              !_componentVersionOverrides
                                  .contains(component.key)
                          ? 'Uses container version'
                          : null,
                      suffixIcon: !widget.allowContainerFields &&
                              _componentVersionOverrides.contains(component.key)
                          ? IconButton(
                              tooltip: 'Use container version',
                              onPressed: () => _update(() =>
                                  _componentVersionOverrides
                                      .remove(component.key)),
                              icon: const Icon(Icons.undo),
                            )
                          : null,
                    ),
                    items: _versionsForComponent(component.key)
                        .map((version) => DropdownMenuItem(
                              value: version,
                              child: Text(version),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _update(() {
                          selection['version'] = value;
                          _componentVersionOverrides.add(component.key);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Text('Launch', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        ..._launchBooleanLabels.entries.map(
          (entry) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.value),
            subtitle: widget.allowContainerFields
                ? null
                : Text(_launchOverrides.contains(entry.key)
                    ? 'Override'
                    : 'Uses container setting'),
            secondary: !widget.allowContainerFields &&
                    _launchOverrides.contains(entry.key)
                ? IconButton(
                    tooltip: 'Use container setting',
                    onPressed: () =>
                        _update(() => _launchOverrides.remove(entry.key)),
                    icon: const Icon(Icons.undo),
                  )
                : null,
            value: _launchBooleans[entry.key]!,
            onChanged: (value) => _update(() {
              _launchBooleans[entry.key] = value;
              _launchOverrides.add(entry.key);
            }),
          ),
        ),
        if (_launchBooleans['fsr'] == true) ...[
          Text('FSR sharpness: ${_fsrSharpness.round()}'),
          Slider(
            value: _fsrSharpness,
            min: 1,
            max: 5,
            divisions: 4,
            label: _fsrSharpness.round().toString(),
            onChanged: (value) => _update(() {
              _fsrSharpness = value;
              _launchOverrides.add('fsrSharpness');
            }),
          ),
        ],
        const SizedBox(height: 8),
        TextFormField(
          controller: _frameRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'DXVK frame rate',
            hintText: 'Unlimited',
            helperText: !widget.allowContainerFields && !_frameRateOverride
                ? 'Uses container setting'
                : 'Leave empty for no frame-rate limit.',
            border: const OutlineInputBorder(),
            suffixIcon: !widget.allowContainerFields && _frameRateOverride
                ? IconButton(
                    tooltip: 'Use container setting',
                    onPressed: () => _update(() => _frameRateOverride = false),
                    icon: const Icon(Icons.undo),
                  )
                : null,
          ),
          onChanged: (_) {
            _frameRateOverride = true;
            widget.onChanged(_value());
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text('Environment',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            if (!widget.allowContainerFields && _environmentOverride)
              TextButton.icon(
                onPressed: () => _update(() => _environmentOverride = false),
                icon: const Icon(Icons.undo),
                label: const Text('Use container environment'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_environment.length, (index) {
          final entry = _environment[index];
          return Padding(
            key: ObjectKey(entry),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: entry.key,
                    decoration: const InputDecoration(
                      hintText: 'VARIABLE',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      entry.key = value;
                      _environmentOverride = true;
                      widget.onChanged(_value());
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('='),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: entry.value,
                    decoration: const InputDecoration(
                      hintText: 'value',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      entry.value = value;
                      _environmentOverride = true;
                      widget.onChanged(_value());
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Remove environment variable',
                  onPressed: () => _update(() {
                    _environment.removeAt(index);
                    _environmentOverride = true;
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () => _update(() {
            _environment.add(_EnvironmentEntry('', ''));
            _environmentOverride = true;
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add environment variable'),
        ),
      ],
    );
  }
}
