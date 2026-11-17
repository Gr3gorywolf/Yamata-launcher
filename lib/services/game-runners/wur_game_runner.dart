import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/models/runner_configuration.dart';
import 'package:yamata_launcher/ui/widgets/wur/wur_emulator_settings.dart';
import 'package:yamata_launcher/ui/widgets/wur/wur_runner_settings.dart';

class WurContainer {
  final String name;
  final bool isDefault;
  final String runtime;
  final bool initialized;
  final String prefix;

  const WurContainer({
    required this.name,
    required this.isDefault,
    required this.runtime,
    required this.initialized,
    required this.prefix,
  });

  factory WurContainer.fromJson(Map<String, dynamic> json) => WurContainer(
        name: json['name']?.toString() ?? '',
        isDefault: json['default'] == true,
        runtime: json['runtime']?.toString() ?? '',
        initialized: json['initialized'] == true,
        prefix: json['prefix']?.toString() ?? '',
      );
}

class WurConfigurationOptions {
  final List<WurContainer> containers;
  final Map<String, List<String>> componentVersions;
  final Map<String, List<String>> runtimeVersions;

  const WurConfigurationOptions({
    required this.containers,
    required this.componentVersions,
    this.runtimeVersions = const {},
  });
}

class WurGameRunner implements GameRunner {
  static const installScriptUrl =
      'https://raw.githubusercontent.com/Gr3gorywolf/Wine-Unified-Runner/main/scripts/install.sh';
  static const componentKeys = <String, String>{
    'dxvk': 'DXVK',
    'dxvkNvapi': 'DXVK NVAPI',
    'vkd3d': 'VKD3D',
    'eacRuntime': 'Easy Anti-Cheat runtime',
    'battleyeRuntime': 'BattlEye runtime',
  };
  static const _componentConfigKeys = <String, String>{
    'dxvk': 'dxvk',
    'dxvk-macos': 'dxvk',
    'dxvk-nvapi': 'dxvkNvapi',
    'vkd3d': 'vkd3d',
    'eac-runtime': 'eacRuntime',
    'battleye-runtime': 'battleyeRuntime',
  };
  static const runtimeSourceLabels = <String, String>{
    'ge-proton': 'GE-Proton',
    'proton': 'Valve Proton',
    'proton-archive': 'Proton Archive (Kron4ek)',
    'proton-cachyos': 'Proton-CachyOS',
    'wine-lutris': 'Wine-Lutris',
    'wine-crossover': 'Wine-CrossOver',
    'wine-staging-macos': 'Wine-Staging macOS',
    'game-porting-toolkit': 'Game Porting Toolkit',
  };

  static List<String> get compatibleRuntimeSources {
    if (Platform.isMacOS) {
      return [
        'wine-crossover',
        'wine-staging-macos',
        if (Abi.current() == Abi.macosArm64) 'game-porting-toolkit',
      ];
    }
    return const [
      'ge-proton',
      'proton',
      'proton-archive',
      'proton-cachyos',
      'wine-lutris',
    ];
  }

  String _executablePath = '';
  bool _isAvailable = false;

  @override
  String get runnerId => 'wur';

  @override
  String get name => 'WUR';

  @override
  bool get isSupportedOnCurrentPlatform => Platform.isLinux || Platform.isMacOS;

  @override
  String get executablePath => _executablePath;

  @override
  List<String> get defaultExecutablePaths {
    if (!isSupportedOnCurrentPlatform) return const [];
    final home = Platform.environment['HOME'];
    return home == null || home.isEmpty
        ? const []
        : [p.join(home, 'wur', 'wur')];
  }

  @override
  Future<bool> isExecutableAvailable(String executablePath) async {
    if (!isSupportedOnCurrentPlatform) return false;
    final path = executablePath.trim();
    return path.isNotEmpty && await File(path).exists();
  }

  @override
  Future<void> setExecutablePath(String executablePath) async {
    final path = executablePath.trim();
    _executablePath = path;
    final available = await isExecutableAvailable(path);
    if (_executablePath == path) _isAvailable = available;
  }

  @override
  bool get isRunnerInstalled => _isAvailable;

  @override
  Future<bool> canRunOnConsole(String console) async {
    return isSupportedOnCurrentPlatform && console == 'windows';
  }

  Future<ProcessResult> runCommand(List<String> arguments) async {
    if (executablePath.isEmpty) throw Exception('WUR is not configured.');
    final result = await Process.run(executablePath, arguments);
    if (result.exitCode != 0) {
      final error = result.stderr.toString().trim();
      throw Exception(
          error.isEmpty ? 'WUR exited with code ${result.exitCode}.' : error);
    }
    return result;
  }

  Future<void> runCommandWithStatus(
    List<String> arguments,
    ValueChanged<String> onStatus,
  ) async {
    if (executablePath.isEmpty) throw Exception('WUR is not configured.');
    final process = await Process.start(executablePath, arguments);
    final errors = StringBuffer();

    Future<void> read(
      Stream<List<int>> stream, {
      bool isError = false,
      bool reportStatus = false,
    }) async {
      await for (final chunk in stream.transform(utf8.decoder)) {
        if (isError) errors.write(chunk);
        final message = chunk
            .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
            .split(RegExp(r'[\r\n]+'))
            .map((line) => line.trim())
            .lastWhere((line) => line.isNotEmpty, orElse: () => '');
        if (reportStatus && message.isNotEmpty) onStatus(message);
      }
    }

    await Future.wait([
      read(process.stdout),
      read(process.stderr, isError: true, reportStatus: true),
    ]);
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      final error = errors.toString().trim();
      throw Exception(
        error.isEmpty ? 'WUR exited with code $exitCode.' : error,
      );
    }
  }

  Future<dynamic> runJson(List<String> arguments) async {
    final result = await runCommand([...arguments, '--json']);
    final output = result.stdout.toString().trim();
    return output.isEmpty ? null : jsonDecode(output);
  }

  Future<List<WurContainer>> listContainers() async {
    final json = await runJson(['container', 'list']);
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map((item) => WurContainer.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.name.isNotEmpty)
        .toList();
  }

  Future<WurConfigurationOptions> loadConfigurationOptions({
    bool includeRuntimes = false,
  }) async {
    final containers = await listContainers();
    dynamic componentJson;
    try {
      componentJson = await runJson(['component', 'list', '--remote']);
    } catch (_) {
      componentJson = await runJson(['component', 'list']);
    }
    final versions = <String, List<String>>{
      for (final key in componentKeys.keys) key: ['latest'],
    };
    if (componentJson is List) {
      for (final raw in componentJson.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final cliName = item['name']?.toString();
        final version = item['version']?.toString();
        if (cliName == null || version == null) continue;
        final configKey = _componentConfigKeys[cliName];
        if (configKey != null && !versions[configKey]!.contains(version)) {
          versions[configKey]!.add(version);
        }
      }
    }
    final runtimeVersions = <String, List<String>>{};
    if (includeRuntimes) {
      dynamic runtimeJson;
      try {
        runtimeJson = await runJson([
          'runtime',
          'list',
          '--remote',
          '--limit',
          '30',
        ]);
      } catch (_) {
        runtimeJson = await runJson(['runtime', 'list']);
      }
      for (final source in compatibleRuntimeSources) {
        runtimeVersions[source] = ['latest'];
      }
      if (runtimeJson is List) {
        for (final raw in runtimeJson.whereType<Map>()) {
          final item = Map<String, dynamic>.from(raw);
          final source = item['source']?.toString();
          final version = item['version']?.toString();
          if (source == null ||
              version == null ||
              !runtimeVersions.containsKey(source)) {
            continue;
          }
          if (!runtimeVersions[source]!.contains(version)) {
            runtimeVersions[source]!.add(version);
          }
        }
      }
    }
    return WurConfigurationOptions(
      containers: containers,
      componentVersions: versions,
      runtimeVersions: runtimeVersions,
    );
  }

  Future<String> install() async {
    if (!isSupportedOnCurrentPlatform) {
      throw Exception('WUR only supports Linux and macOS.');
    }
    final response = await http.get(Uri.parse(installScriptUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Could not download the WUR installer (${response.statusCode}).');
    }
    final temp = await Directory.systemTemp.createTemp('yamata-wur-install-');
    try {
      final script = File(p.join(temp.path, 'install.sh'));
      await script.writeAsBytes(response.bodyBytes, flush: true);
      final result = await Process.run('/bin/bash', [script.path]);
      if (result.exitCode != 0) {
        final error = result.stderr.toString().trim();
        throw Exception(error.isEmpty ? 'WUR installation failed.' : error);
      }
    } finally {
      await temp.delete(recursive: true);
    }
    final installedPath = defaultExecutablePaths.firstOrNull;
    if (installedPath == null || !await isExecutableAvailable(installedPath)) {
      throw Exception(
          'WUR finished installing, but its executable was not found.');
    }
    return installedPath;
  }

  @override
  Widget buildEmulatorSettingsConfiguration({
    required String console,
    required RunnerConfiguration configuration,
    required ValueChanged<RunnerConfiguration> onChanged,
  }) {
    return WurEmulatorSettings(
      runner: this,
      configuration: configuration,
      onChanged: onChanged,
    );
  }

  @override
  Widget? buildRunnerSettings(
    BuildContext context, {
    VoidCallback? onRefresh,
  }) {
    return WurRunnerSettings(
      key: ValueKey(executablePath),
      runner: this,
      onRefresh: onRefresh,
    );
  }

  List<String> _overrideArguments(RunnerConfiguration? configuration) {
    if (configuration == null) return const [];
    final settings = configuration.settings;
    final args = <String>[];
    final container = settings['container'];
    if (container is String && container.isNotEmpty) {
      args.addAll(['--container', container]);
    }
    final components = settings['components'];
    if (components is Map) {
      for (final entry in components.entries) {
        final key = entry.key.toString();
        if (!componentKeys.containsKey(key)) continue;
        if (entry.value is Map) {
          final selection = Map<String, dynamic>.from(entry.value as Map);
          final enabled = selection['enabled'];
          final version = selection['version']?.toString() ?? '';
          if (enabled is bool) {
            args.addAll([
              '--set',
              'components.$key.enabled=${jsonEncode(enabled)}',
            ]);
          }
          if (version.isNotEmpty) {
            args.addAll([
              '--set',
              'components.$key.version=${jsonEncode(version)}',
            ]);
          }
        } else {
          // Backward compatibility with the original version-only shape.
          final version = entry.value?.toString() ?? '';
          if (version.isNotEmpty) {
            args.addAll([
              '--set',
              'components.$key.version=${jsonEncode(version)}',
            ]);
          }
        }
      }
    }
    final launch = settings['launch'] is Map
        ? Map<String, dynamic>.from(settings['launch'] as Map)
        : <String, dynamic>{
            if (settings['fsr'] is bool) 'fsr': settings['fsr'],
            if (settings['fsrSharpness'] is num)
              'fsrSharpness': settings['fsrSharpness'],
            if (settings['environment'] is Map)
              'environment': settings['environment'],
          };
    const launchKeys = {
      'enableEsync',
      'enableFsync',
      'enableMsync',
      'enableWayland',
      'enableHdr',
      'enableWow64',
      'showFps',
      'dxvkFrameRate',
      'fsr',
      'fsrSharpness',
      'verboseLogs',
    };
    for (final key in launchKeys) {
      if (!launch.containsKey(key)) continue;
      final value = launch[key];
      if (value == null || value is bool || value is num) {
        args.addAll(['--set', 'launch.$key=${jsonEncode(value)}']);
      }
    }
    final environment = launch['environment'];
    if (environment is Map) {
      for (final entry in environment.entries) {
        final key = entry.key.toString().trim();
        if (key.isNotEmpty) {
          args.addAll([
            '--set',
            'launch.environment.$key=${jsonEncode(entry.value.toString())}',
          ]);
        }
      }
    }
    return args;
  }

  @override
  Future<Process?> launch(
      RomLibraryItem rom, EmulatorSetting emulatorSetting) async {
    final executable = rom.filePath;
    if (executable == null || executable.isEmpty) {
      throw Exception('The game executable path is empty.');
    }
    final args = <String>[
      'run',
      executable,
      ..._overrideArguments(emulatorSetting.runnerConfig),
    ];
    final gameArguments = [
      emulatorSetting.launchParams.trim(),
      rom.openParams?.trim() ?? '',
    ].where((value) => value.isNotEmpty).join(' ');
    if (gameArguments.isNotEmpty) {
      args.addAll(['--', ...gameArguments.split(RegExp(r'\s+'))]);
    }
    return Process.start(
      executablePath,
      args,
      workingDirectory: p.dirname(executable),
    );
  }

  @override
  Future<void> openRunner() async {
    await Process.start(executablePath, ['container', 'exec', 'explorer.exe']);
  }
}
