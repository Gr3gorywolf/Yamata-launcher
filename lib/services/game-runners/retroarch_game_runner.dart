import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:yamata_launcher/models/argument_group.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/os_service.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/utils/flatpak_utils.dart';
import 'package:yamata_launcher/utils/process_helper.dart';
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

    var launchParams = "-L ${installedCores.first}";
    if (emulatorSetting.launchParams.isNotEmpty) {
      launchParams = emulatorSetting.launchParams;
    }
    if (rom.openParams != null && rom.openParams!.isNotEmpty) {
      launchParams += " ${rom.openParams}";
    }
    if (!launchParams.contains("-L")) {
      launchParams = "-L ${installedCores.first} $launchParams";
    }
    var launchArgs = [...launchParams.split(' '), rom.filePath ?? "", '-v'];
    var executableBinary = this.executablePath;
    if (Platform.isMacOS) {
      executableBinary = await SystemHelpers.resolveMacAppExecutable(
          executablesByPlatform[OsType.macos]!);
    }
    final command =
        Platform.isWindows ? emulatorSetting.emulatorBinary : executableBinary;
    print("launching retroarch with command $command ${launchArgs.join(' ')}");

    final process = Platform.isLinux
        ? await FlatpakUtils.launchFlatpak(command, launchArgs)
        : await Process.start(command, launchArgs);

    ProcessHelper.pipeProcessOutput(
      process: process,
      onLog: (String line) {
        print('RetroArch: $line');
      },
    );
    return process;
  }

  @override
  Future<List<ArgumentGroup>> getAvailableParams(
      String console, String executablePath) async {
    var coresPath = await _getCoresPath(executablePath);
    var installedCores = [];
    if (coresPath != null) {
      installedCores = await _getConsoleInstalledCores(console, coresPath);
    }
    var params = [
      ArgumentGroup(
        key: 'cores',
        name: 'Core to use',
        singleSelect: true,
        arguments: installedCores.map((core) {
          var coreName = p.basenameWithoutExtension(core);
          return Argument("${coreName}", '-L $core');
        }).toList(),
      ),
      ArgumentGroup(
        key: 'system',
        name: 'System options',
        singleSelect: false,
        arguments: [
          Argument("Launch fullscreen", "-f"),
          Argument("Show RetroArch menu on launch", "--menu")
        ],
      ),
    ];
    return params;
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
