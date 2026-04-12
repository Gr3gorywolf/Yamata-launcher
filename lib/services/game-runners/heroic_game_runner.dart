import 'dart:convert';
import 'dart:io';

import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/services/os_service.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/utils/flatpak_utils.dart';
import 'package:yamata_launcher/utils/process_helper.dart';

class HeroicGameRunner implements GameRunner {
  var dataFolderByPlatform = {
    OsType.linux:
        '${Platform.environment['HOME']}/.var/app/com.heroicgameslauncher.hgl/config/heroic',
    OsType.macos:
        '${Platform.environment['HOME']}/Library/Application Support/Heroic',
  };

  var executablesByPlatform = {
    OsType.linux: 'com.heroicgameslauncher.hgl',
    OsType.macos: '/Applications/Heroic.app/Contents/MacOS/Heroic',
  };

  @override
  String get name => 'Heroic Games Launcher';

  @override
  String get executablePath => executablesByPlatform[OsService.osType] ?? '';

  @override
  bool get isRunnerAvailable {
    final executablePath = executablesByPlatform[OsService.osType];
    if (executablePath == null) return false;
    if (Platform.isLinux) {
      return Directory(this.dataFolderByPlatform[OsType.linux]!).existsSync() ||
          FlatpakUtils.cachedFlatpakApps
                  ?.contains('com.heroicgameslauncher.hgl') ==
              true;
    }
    return File(executablePath).existsSync();
  }

  @override
  Future<bool> canRunOnRunner(String console) async {
    if (Platform.isLinux || Platform.isMacOS) {
      return isRunnerAvailable && console == 'windows';
    }
    return false;
  }

  String _generateId(String slug) {
    return base64Url.encode(utf8.encode(slug)).replaceAll('=', '');
  }

  Future<Map<String, dynamic>> _readJson(File file) async {
    if (!await file.exists()) return {};
    return jsonDecode(await file.readAsString());
  }

  Future<void> _writeJson(File file, Map<String, dynamic> data) async {
    await file.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Map<String, String> _buildLaunchEnvironment() {
    final environment = {...Platform.environment};
    final removedKeys = <String>[];

    // Inherited Electron/Node flags can make Heroic boot in Node mode,
    // which causes Electron CLI switches like --no-gui to fail.
    if (environment.remove('ELECTRON_RUN_AS_NODE') != null) {
      removedKeys.add('ELECTRON_RUN_AS_NODE');
    }
    if (environment.remove('NODE_OPTIONS') != null) {
      removedKeys.add('NODE_OPTIONS');
    }

    if (removedKeys.isNotEmpty) {
      print(
          'Sanitized Heroic launch environment by removing: ${removedKeys.join(', ')}');
    }

    return environment;
  }

  String _buildLaunchUrl(String gameId) {
    return 'heroic://launch?appName=$gameId&runner=sideload';
  }

  String _macOsAppBundlePath() {
    return p.dirname(p.dirname(p.dirname(executablePath)));
  }

  Future<ProcessResult> _runLauncherCommand(
    String command,
    List<String> args,
  ) async {
    return Process.run(command, args,
        environment: _buildLaunchEnvironment(),
        includeParentEnvironment: false);
  }

  Future<void> closeLauncher() async {
    if (Platform.isMacOS) {
      print('Closing Heroic launcher before launching the game');

      await _runLauncherCommand('osascript', [
        '-e',
        'tell application "Heroic" to quit',
      ]);

      await Future.delayed(const Duration(seconds: 1));

      final killResult = await _runLauncherCommand('killall', ['Heroic']);
      if (killResult.exitCode == 0) {
        print('Forced Heroic launcher shutdown before relaunch');
        await Future.delayed(const Duration(milliseconds: 500));
      }
      return;
    }

    if (Platform.isLinux) {
      final killResult =
          await _runLauncherCommand('pkill', ['-f', executablePath]);
      if (killResult.exitCode == 0) {
        print('Closed Heroic launcher before relaunch');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  @override
  Future<Process?> launchOnRunner(RomLibraryItem rom) async {
    final dataFolder = dataFolderByPlatform[OsService.osType];
    if (dataFolder == null) throw Exception('Unsupported OS');

    final libraryFile =
        File(p.join(dataFolder, 'sideload_apps', 'library.json'));
    final gamesConfigDir = Directory(p.join(dataFolder, 'GamesConfig'));
    final configFile = File(p.join(dataFolder, 'config.json'));

    var gameExecutablePath = rom.filePath ?? "";
    final folderPath = p.dirname(gameExecutablePath);

    final libraryJson = await _readJson(libraryFile);
    final games = List<Map<String, dynamic>>.from(libraryJson['games'] ?? []);

    String? existingId;

    for (final game in games) {
      if (game['install']?['executable'] == gameExecutablePath) {
        existingId = game['app_name'];
        break;
      }
    }

    String gameId;

    if (existingId != null) {
      gameId = existingId;
    } else {
      gameId = _generateId(rom.rom.slug);

      final configJson = await _readJson(configFile);
      final defaultPrefix = configJson['defaultSettings']
              ?['defaultWinePrefix'] ??
          configJson['defaultSettings']?['winePrefix'] ??
          '';

      final newEntry = {
        "runner": "sideload",
        "app_name": gameId,
        "title": rom.rom.name,
        "install": {
          "executable": gameExecutablePath,
          "platform": "Windows",
          "is_dlc": false
        },
        "folder_name": folderPath,
        "art_cover":
            rom.rom.gameplayCovers != null && rom.rom.gameplayCovers!.isNotEmpty
                ? rom.rom.gameplayCovers!.first
                : null,
        "is_installed": true,
        "art_square": rom.rom.portrait,
        "canRunOffline": true,
        "browserUrl": "",
        "customUserAgent": "",
        "launchFullScreen": false
      };

      games.add(newEntry);

      await _writeJson(libraryFile, {
        "games": games,
      });

      final gameConfig = {
        gameId: {
          "autoInstallDxvk": true,
          "autoInstallDxvkNvapi": false,
          "autoInstallVkd3d": false,
          "preferSystemLibs": false,
          "enableEsync": true,
          "enableMsync": true,
          "enableFsync": false,
          "enableWineWayland": false,
          "enableHDR": false,
          "enableWoW64": false,
          "nvidiaPrime": false,
          "enviromentOptions": [],
          "wrapperOptions": [],
          "showFps": true,
          "useGameMode": false,
          "battlEyeRuntime": false,
          "eacRuntime": false,
          "language": "",
          "beforeLaunchScriptPath": "",
          "afterLaunchScriptPath": "",
          "verboseLogs": true,
          "advertiseAvxForRosetta": false,
          "enableQuickSavesMenu": false,
          "wineCrossoverBottle": "Heroic",
          "winePrefix": defaultPrefix
        },
        "version": "v0",
        "explicit": true
      };

      final gameConfigFile = File(p.join(gamesConfigDir.path, '$gameId.json'));

      await _writeJson(gameConfigFile, gameConfig);
    }

    await closeLauncher();

    final launchUrl = _buildLaunchUrl(gameId);
    final command = Platform.isMacOS ? 'open' : this.executablePath;
    final launchArgs = Platform.isMacOS
        ? [
            '-W',
            '-a',
            _macOsAppBundlePath(),
            '--args',
            '--no-gui',
            '--no-sandbox',
            launchUrl
          ]
        : ['--no-gui', '--no-sandbox', launchUrl];

    print("launching heroic with command $command ${launchArgs.join(' ')}");

    final process = Platform.isLinux
        ? await FlatpakUtils.launchFlatpak(command, launchArgs)
        : await Process.start(command, launchArgs,
            environment: _buildLaunchEnvironment(),
            includeParentEnvironment: false);

    ProcessHelper.pipeProcessOutput(process: process, onLog: print);
    return process;
  }
}
