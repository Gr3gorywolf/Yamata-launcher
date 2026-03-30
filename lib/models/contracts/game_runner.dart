import 'dart:io';

import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';

abstract class GameRunner {
  String get name;
  String get executablePath;
  bool get isExecutableAvailable;
  Future<bool> canRunOnRunner(RomLibraryItem rom);
  Future<Process?> launchOnRunner(RomLibraryItem rom);
}
