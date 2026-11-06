import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/models/runner_configuration.dart';

abstract class GameRunner {
  /// Stable persisted identifier. Never use the display name as a key.
  String get runnerId;
  String get name;
  String get executablePath;
  bool get isRunnerInstalled;
  Future<bool> canRunOnConsole(String console);
  Future<Process?> launch(RomLibraryItem rom, EmulatorSetting emulatorSetting);

  /// Configuration for this runner inside an emulator setting (or a game
  /// override). The widget is owned by the runner, rather than by Yamata.
  Widget buildEmulatorSettingsConfiguration({
    required String console,
    required RunnerConfiguration configuration,
    required ValueChanged<RunnerConfiguration> onChanged,
  });

  /// Optional settings for the runner itself, independent of any emulator.
  /// Returning null means the integrations page opens the runner directly.
  Widget? buildRunnerSettings(BuildContext context);

  Future<void> openRunner();
}
