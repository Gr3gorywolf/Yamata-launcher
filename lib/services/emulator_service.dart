import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/emulator_settings_dao.dart';
import 'package:yamata_launcher/models/contracts/game_runner.dart';
import 'package:yamata_launcher/models/emulator_intent.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/repository/emulator_intents_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/game-runners/heroic_game_runner.dart';
import 'package:yamata_launcher/services/game-runners/retroarch_game_runner.dart';
import 'package:yamata_launcher/services/native/intents_android_interface.dart';
import 'package:android_intent_plus/flag.dart' as flag;
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/utils/flatpak_utils.dart';
import 'package:yamata_launcher/utils/process_helper.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';

enum EmulatorLaunchResult { success, failedToLaunch, needsExtraction }

class EmulatorService {
  static Map<String, Timer> _activeGames = {};
  static Map<String, Process> _activeGamesProcesses = {};
  static Map<String, Map<String, String>> _emulatorIntents = {};
  static List<GameRunner> runners = [
    RetroarchGameRunner(),
    HeroicGameRunner(),
  ];

  /**
   * Since the emulator intents have interpolated values, we need to parse them each time we use them.
   */
  static EmulatorIntent _parseEmulatorIntent(
      String jsonString, String path, String uri) {
    jsonString = jsonString.replaceAll("{file.uri}", uri);
    jsonString = jsonString.replaceAll("{file.path}", path);
    return EmulatorIntent.fromJson(jsonDecode(jsonString));
  }

  static List<String> getEmulatorPackagesForConsole(String console) {
    var intents = _emulatorIntents[console];
    if (intents == null) {
      return [];
    }
    return intents.keys.toList();
  }

  /*
    * Loads emulator intents from the local file system.
    */
  static Future loadEmulatorIntents() async {
    var file = File(FileSystemService.emulatorIntentsFilePath);
    if (await file.exists() == false) {
      return;
    }
    var content = await file.readAsString();
    for (var consoleIntents in jsonDecode(content).entries) {
      Map<String, String> unparsedIntents = {};
      for (var intent in consoleIntents.value) {
        unparsedIntents[intent['package']] = jsonEncode(intent);
      }
      _emulatorIntents[consoleIntents.key] = unparsedIntents;
    }
    print("Loaded ${_emulatorIntents.length} emulator intents");
  }

  /**
   * Launches an emulator intent on Android devices.
   */
  static Future<EmulatorLaunchResult> launchEmulatorIntent(
      String console, String packageName, String filePath) async {
    try {
      print(
          'Launching emulator with package: $packageName and file: $filePath');
      var intents = _emulatorIntents[console];
      if (intents == null) {
        intents = {};
      }
      var matchedIntent = EmulatorIntent(
          package: packageName,
          action: 'android.intent.action.VIEW',
          type: '*/*');
      var filePathUri =
          await IntentsAndroidInterface.getIntentUri(filePath) ?? filePath;
      if (intents[packageName] != null) {
        matchedIntent =
            _parseEmulatorIntent(intents[packageName]!, filePath, filePathUri);
      }
      var isCompressed = VALID_COMPRESSED_EXTENSIONS
          .any((ext) => filePath.toLowerCase().endsWith(ext));
      if (matchedIntent.requireExtraction == true && isCompressed) {
        return EmulatorLaunchResult.needsExtraction;
      }

      var componentName = matchedIntent.activity != null
          ? matchedIntent.activity
              ?.replaceFirst(matchedIntent.package! + "/", '')
          : null;
      print(
          'Using component name: $componentName and extras: ${matchedIntent.extras}');
      await IntentsAndroidInterface.grantUriPermission(
          filePathUri, packageName);
      final intent = AndroidIntent(
          action: matchedIntent.action,
          package: matchedIntent.package,
          componentName: componentName,
          data: matchedIntent.data,
          arguments: matchedIntent.extras,
          category: matchedIntent.category,
          type: matchedIntent.type ?? "*/*",
          flags: [
            flag.Flag.FLAG_ACTIVITY_NEW_TASK,
            flag.Flag.FLAG_GRANT_READ_URI_PERMISSION,
            flag.Flag.FLAG_GRANT_WRITE_URI_PERMISSION,
            flag.Flag.FLAG_ACTIVITY_CLEAR_TASK
          ]);

      await intent.launch();
    } on Exception catch (e) {
      print("Error launching emulator: $e");
      AlertsService.showErrorSnackbar('Failed to launch emulator',
          exception: e);
      return EmulatorLaunchResult.failedToLaunch;
    }
    return EmulatorLaunchResult.success;
  }

  static closeRunningRom(String slug) {
    if (_activeGamesProcesses.containsKey(slug)) {
      _activeGamesProcesses[slug]?.kill();
      _activeGamesProcesses.remove(slug);
    }
    return Future.value();
  }

  // Checks if the console is the native platform, meaning it doesn't require an emulator to run.
  static bool isNativePlatform(String console) {
    if (Platform.isWindows && console == CONSOLE_SLUGS.windows.name) {
      return true;
    }

    if (Platform.isLinux && console == CONSOLE_SLUGS.linux.name) {
      return true;
    }

    if (Platform.isMacOS && console == CONSOLE_SLUGS.macos.name) {
      return true;
    }
    return false;
  }

  /**
   * Checks if there's an available game runner for the given game, and returns it.
   */
  static Future<List<GameRunner>> getAvailableRunners(String console) async {
    if (Platform.isLinux) {
      await FlatpakUtils.getInstalledFlatpakAppIds();
    }
    final availableRunners = <GameRunner>[];
    for (final runner in runners) {
      if (await runner.canRunOnRunner(console)) {
        availableRunners.add(runner);
      }
    }
    return availableRunners;
  }

  /**
   * Opens a ROM using the configured emulator.
   */
  static Future openRom(RomLibraryItem download) async {
    if (db == null) return;

    EmulatorLaunchResult emulatorLaunchResult = EmulatorLaunchResult.success;

    final rom = download.rom;
    final consoleKey = rom.console;
    final slug = rom.slug;

    var emulatorSetting = await EmulatorSettingsDao(db!).get(consoleKey);
    var isNativePlatform = EmulatorService.isNativePlatform(consoleKey);
    if (emulatorSetting == null) {
      if (isNativePlatform) {
        print("Console $consoleKey is a native platform, launching directly");
        emulatorSetting = EmulatorSetting(
            console: consoleKey, emulatorBinary: "", launchParams: "");
      } else {
        final consoleName =
            ConsoleService.getConsoleFromName(consoleKey)?.name ?? consoleKey;

        AlertsService.showErrorSnackbar(
          "No emulator configured for $consoleName. Please set it up in settings.",
        );
        return;
      }
    }

    final provider =
        Provider.of<LibraryProvider>(navigatorContext!, listen: false);

    void handleUpdateLibraryItem({bool addTime = false}) {
      final currentItem = provider.getLibraryItem(slug);
      if (currentItem == null) return;

      if (addTime) {
        currentItem.playTimeMins += 1;
      }

      currentItem.lastPlayedAt = DateTime.now();
      provider.updateLibraryItem(currentItem);
    }

    final stopWatch = Timer.periodic(const Duration(minutes: 1), (_) async {
      handleUpdateLibraryItem(addTime: true);
    });

    _activeGames[slug] = stopWatch;

    final openParams = download.openParams ?? "";
    var filePath = download.filePath ?? "";

    final overrideEmulator = download.overrideEmulator;
    var emulatorBinary =
        (overrideEmulator != null && overrideEmulator.isNotEmpty)
            ? overrideEmulator
            : emulatorSetting.emulatorBinary;
    // If the emulator binary is empty and its desktop then its a direct launch
    if (emulatorBinary.isEmpty &&
        !filePath.isEmpty &&
        FileSystemService.isDesktop) {
      emulatorBinary = filePath;
      filePath = "";
    }

    final launchParams = <String>[
      if (emulatorSetting.launchParams.isNotEmpty) emulatorSetting.launchParams,
      if (openParams.isNotEmpty) openParams,
      filePath,
    ];

    print("Launching emulator $emulatorBinary with params: $launchParams");

    handleUpdateLibraryItem();
    provider.setGameRunning(slug, true);

    try {
      if (Platform.isAndroid) {
        emulatorLaunchResult = await EmulatorService.launchEmulatorIntent(
          consoleKey,
          emulatorBinary,
          filePath,
        );
      } else {
        Process? process;
        var availableRunners = await getAvailableRunners(consoleKey);
        print(availableRunners);
        if (availableRunners.isNotEmpty) {
          for (var runner in availableRunners) {
            if (emulatorBinary.contains(runner.executablePath)) {
              Process? runnerProcess = null;
              try {
                runnerProcess =
                    await runner.launchOnRunner(download, emulatorSetting);
              } on Exception catch (e) {
                print("Error checking runner availability: $e");
                AlertsService.showErrorSnackbar(
                    "Failed to launch the game with ${runner.name}",
                    exception: e);
                return;
              }

              if (runnerProcess != null) {
                process = runnerProcess;
              }
              break;
            }
          }
        }
        print(process);
        if (process == null) {
          if (Platform.isMacOS) {
            final execPath =
                await SystemHelpers.resolveMacAppExecutable(emulatorBinary);
            print("resolved emulator binary to ${execPath}");
            process = await Process.start(execPath, launchParams);
          } else {
            if (Platform.isLinux &&
                await FlatpakUtils.isFlatpakExecutable(emulatorBinary)) {
              process = await FlatpakUtils.launchFlatpak(
                  emulatorBinary, launchParams);
              ProcessHelper.pipeProcessOutput(
                  process: process,
                  progressPrefix: "",
                  onLog: (output) => print("[Flatpak] $output"));
            } else {
              process = await Process.start(emulatorBinary, launchParams,
                  mode: ProcessStartMode.inheritStdio,
                  workingDirectory: p.dirname(filePath));
            }
          }
        }
        _activeGamesProcesses[slug] = process;

        await process.exitCode;
      }
    } on Exception catch (err) {
      AlertsService.showErrorSnackbar("Failed to open the rom", exception: err);
    } finally {
      final activeTimer = _activeGames[slug];
      if (_activeGamesProcesses[slug] != null) {
        _activeGamesProcesses.remove(slug);
      }
      if (activeTimer != null) {
        activeTimer.cancel();
        _activeGames.remove(slug);

        provider.setGameRunning(slug, false);
        print("Stopped playtime tracking for $slug");
      }
    }

    if (Platform.isAndroid &&
        emulatorLaunchResult == EmulatorLaunchResult.needsExtraction) {
      AlertsService.showAlert(
        navigatorContext!,
        "Rom needs to be extracted",
        "The selected emulator requires the ROM to be extracted before launching, do you want to extract it now?",
        acceptTitle: "Yes",
        callback: () {
          RomService.extractRom(download);
        },
      );
    }
  }
}
