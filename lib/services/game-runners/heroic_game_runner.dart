import 'dart:convert';
import 'dart:io';

import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/services/os_service.dart';
import 'package:path/path.dart' as p;
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
  bool get isExecutableAvailable {
    final executablePath = executablesByPlatform[OsService.osType];
    if (executablePath == null) return false;
    return File(executablePath).existsSync();
  }

  @override
  Future<bool> canRunOnRunner(RomLibraryItem libItem) async {
    if (Platform.isLinux || Platform.isMacOS) {
      return isExecutableAvailable && libItem.rom.console == 'windows';
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

    // 🔥 Lanzar Heroic
    print(
        "launching heroic with executable ${this.executablePath} --no-gui --no-sandbox heroic://launch/sideload/$gameId");

    final process = await Process.start(this.executablePath,
        ['--no-gui', '--no-sandbox', 'heroic://launch/sideload/$gameId'],
        environment: {...Platform.environment});

    ProcessHelper.pipeProcessOutput(process: process, onLog: print);
    return process;
  }
}
