import 'dart:io';

import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';

abstract class GameRunner {
  String get name;
  String get executablePath;
  bool get isRunnerAvailable;
  bool get canSyncLibrary;
  bool get autoSyncWithLibrary;
  Future<void> syncLibrary(List<RomLibraryItem> items);
  Future<void> setAutosync(bool value);
  Future<bool> canRunOnRunner(String console);
  Future<Process?> launchOnRunner(RomLibraryItem rom);
}
