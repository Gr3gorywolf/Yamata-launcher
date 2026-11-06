import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/models/runner_configuration.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/os_service.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/utils/flatpak_utils.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';

class RetroarchGameRunner implements GameRunner {
  var dataFolderByPlatform = {
    OsType.windows: '${Platform.environment['APPDATA']}\\RetroArch',
    OsType.linux:
        '${Platform.environment['HOME']}/.var/app/org.libretro.RetroArch/config/retroarch',
    OsType.macos:
        '${Platform.environment['HOME']}/Library/Application Support/RetroArch',
  };

  var executablesByPlatform = {
    OsType.windows: 'retroarch.exe',
    OsType.linux: 'org.libretro.RetroArch',
    OsType.macos: '/Applications/RetroArch.app',
  };

  @override
  String get runnerId => 'retroarch';

  @override
  String get name => 'RetroArch';

  @override
  String get executablePath => executablesByPlatform[OsService.osType] ?? '';

  @override
  bool get isRunnerInstalled {
    final executablePath = executablesByPlatform[OsService.osType];
    if (executablePath == null) return false;
    if (Platform.isLinux) {
      return Directory(this.dataFolderByPlatform[OsType.linux]!).existsSync() ||
          FlatpakUtils.cachedFlatpakApps?.contains('org.libretro.RetroArch') ==
              true;
    }
    return File(executablePath).existsSync() ||
        Directory(executablePath).existsSync();
  }

  @override
  Future<bool> canRunOnConsole(String console) async {
    var coresByConsole = await getCoresByConsole(console);
    return coresByConsole.isNotEmpty;
  }

  @override
  Future<Process?> launch(
      RomLibraryItem rom, EmulatorSetting emulatorSetting) async {
    var coresPath = await _getCoresPath(emulatorSetting.emulatorBinary);
    if (coresPath == null) {
      throw Exception('Cores folder not found for RetroArch');
    }
    var installedCores =
        await _getConsoleInstalledCores(rom.rom.console, coresPath);
    if (installedCores.isEmpty) {
      throw Exception(
          'No installed RetroArch cores found for ${ConsoleService.getConsoleFromName(rom.rom.console)?.name}');
    }

    final configuredCore = emulatorSetting.runnerConfig?.settings['core'];
    final core =
        configuredCore is String && installedCores.contains(configuredCore)
            ? configuredCore
            : installedCores.first;
    // A selected core is runner configuration, not a generic command-line
    // option. Strip legacy -L options so it remains the source of truth.
    final customParams = emulatorSetting.launchParams.replaceAll(
      RegExp(r'(^|\s)-L\s+\S+'),
      '',
    );
    var launchParams = "-L $core $customParams".trim();
    if (rom.openParams != null && rom.openParams!.isNotEmpty) {
      launchParams += " ${rom.openParams}";
    }
    var launchArgs = [...launchParams.split(' '), rom.filePath ?? "", '-v'];
    var executableBinary = this.executablePath;
    if (Platform.isMacOS) {
      executableBinary = await SystemHelpers.resolveMacAppExecutable(
          executablesByPlatform[OsType.macos]!);
    }
    final command =
        Platform.isWindows && emulatorSetting.emulatorBinary.isNotEmpty
            ? emulatorSetting.emulatorBinary
            : executableBinary;
    print("launching retroarch with command $command ${launchArgs.join(' ')}");

    final process = Platform.isLinux
        ? await FlatpakUtils.launchFlatpak(command, launchArgs)
        : await Process.start(command, launchArgs);
    return process;
  }

  @override
  Widget buildEmulatorSettingsConfiguration({
    required String console,
    required RunnerConfiguration configuration,
    required ValueChanged<RunnerConfiguration> onChanged,
  }) {
    return _RetroArchCoreConfiguration(
      runner: this,
      console: console,
      configuration: configuration,
      onChanged: onChanged,
    );
  }

  @override
  Widget? buildRunnerSettings(BuildContext context) => null;

  @override
  Future<void> openRunner() async {
    var command = executablePath;
    if (Platform.isMacOS) {
      command = await SystemHelpers.resolveMacAppExecutable(command);
    }
    if (Platform.isLinux && await FlatpakUtils.isFlatpakExecutable(command)) {
      await FlatpakUtils.launchFlatpak(command, const []);
      return;
    }
    await Process.start(command, const []);
  }

  Future<List<String>> _getConsoleInstalledCores(
      String console, String coresPath) async {
    var coresByConsole = await getCoresByConsole(console);
    var cores = <String>[];
    var coresDir = Directory(coresPath);
    if (coresDir.existsSync()) {
      var files = coresDir.listSync();
      for (var file in files) {
        if (file is File) {
          var fileName = p.basenameWithoutExtension(file.path);
          var foundCore = coresByConsole
              .firstWhere((core) => fileName.contains(core), orElse: () => '');
          if (foundCore.isNotEmpty) {
            cores.add(p.basename(file.path));
          }
        }
      }
    }
    return cores;
  }

  Future<List<String>> getInstalledCoresForConsole(String console) async {
    final coresPath = await _getCoresPath(executablePath);
    if (coresPath == null) {
      return [];
    }
    return _getConsoleInstalledCores(console, coresPath);
  }

  Future<String?> _getCoresPath(String executablePath) async {
    if (Platform.isWindows) {
      var coresPath = p.join(p.dirname(executablePath), 'cores');
      if (Directory(coresPath).existsSync()) {
        return coresPath;
      }
    }

    if (Platform.isLinux || Platform.isMacOS) {
      var dataFolder = dataFolderByPlatform[OsService.osType];
      if (dataFolder != null) {
        var coresPath = p.join(dataFolder, 'cores');
        if (Directory(coresPath).existsSync()) {
          return coresPath;
        }
      }
    }

    return null;
  }

  Future<List<String>> getCoresByConsole(String console) async {
    final byteData = await rootBundle.load("assets/data/retroarch-cores.json");
    final bytes = byteData.buffer.asUint8List();
    var content = String.fromCharCodes(bytes);
    var coresByConsole = Map<String, List<dynamic>>.from(jsonDecode(content));
    return coresByConsole[console]?.cast<String>() ?? [];
  }
}

class _RetroArchCoreConfiguration extends StatefulWidget {
  final RetroarchGameRunner runner;
  final String console;
  final RunnerConfiguration configuration;
  final ValueChanged<RunnerConfiguration> onChanged;

  const _RetroArchCoreConfiguration({
    required this.runner,
    required this.console,
    required this.configuration,
    required this.onChanged,
  });

  @override
  State<_RetroArchCoreConfiguration> createState() =>
      _RetroArchCoreConfigurationState();
}

class _RetroArchCoreConfigurationState
    extends State<_RetroArchCoreConfiguration> {
  late Future<List<String>> _cores;

  @override
  void initState() {
    super.initState();
    _cores = widget.runner.getInstalledCoresForConsole(widget.console);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _cores,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final cores = snapshot.data!;
        final selectedCore = widget.configuration.settings['core'];
        if (cores.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'No compatible RetroArch cores are installed for this platform.',
            ),
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedCore is String && cores.contains(selectedCore)
              ? selectedCore
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'RetroArch core',
            border: OutlineInputBorder(),
          ),
          hint: const Text('Select a core'),
          items: cores
              .map((core) => DropdownMenuItem(
                    value: core,
                    child: Text(p.basenameWithoutExtension(core)),
                  ))
              .toList(),
          onChanged: (core) {
            if (core == null) return;
            widget.onChanged(widget.configuration.copyWith(settings: {
              ...widget.configuration.settings,
              'core': core,
            }));
          },
        );
      },
    );
  }
}
