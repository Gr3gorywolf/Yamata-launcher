import 'dart:io';

import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';

abstract class GameRunner {
  String get name;
  String get executablePath;
  bool get isRunnerAvailable;
  Future<bool> canRunOnRunner(String console);
  Future<Process?> launchOnRunner(
      RomLibraryItem rom, EmulatorSetting emulatorSetting);
  Future<List<GameRunnerParam>> getParams(
      String console, String executablePath);
}

class GameRunnerParam {
  final String name;
  final String value;

  GameRunnerParam(this.name, this.value);
}
