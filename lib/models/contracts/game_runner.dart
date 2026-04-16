import 'dart:io';

import 'package:yamata_launcher/models/argument_group.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';

abstract class GameRunner {
  String get name;
  String get executablePath;
  bool get isRunnerInstalled;
  Future<bool> canRunOnConsole(String console);
  Future<Process?> launch(RomLibraryItem rom, EmulatorSetting emulatorSetting);
  Future<List<ArgumentGroup>> getAvailableParams(
      String console, String executablePath);
}
