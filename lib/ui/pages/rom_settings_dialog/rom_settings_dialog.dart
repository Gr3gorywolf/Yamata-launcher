import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/emulator_settings_dao.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/emulator_setting.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/duration_picker_dialog.dart';
import 'package:yamata_launcher/ui/widgets/emulator_launch_settings_fields.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';
import 'package:yamata_launcher/utils/time_helpers.dart';

class RomSettingsDialog extends StatefulWidget {
  final RomInfo rom;

  const RomSettingsDialog({super.key, required this.rom});

  @override
  State<RomSettingsDialog> createState() => _RomSettingsDialogState();
}

class _RomSettingsDialogState extends State<RomSettingsDialog> {
  final launchParametersController = TextEditingController();
  final overrideEmulatorController = TextEditingController();
  bool _didInitializeControllers = false;
  EmulatorSetting? defaultEmulatorSetting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeControllers) {
      return;
    }

    final provider = Provider.of<LibraryProvider>(context, listen: false);
    final libraryItem = provider.getLibraryItem(widget.rom.slug);
    overrideEmulatorController.text = libraryItem?.overrideEmulator ?? "";
    launchParametersController.text = libraryItem?.openParams ?? "";
    _didInitializeControllers = true;
    _loadDefaultEmulatorSetting();
  }

  @override
  void dispose() {
    launchParametersController.dispose();
    overrideEmulatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LibraryProvider>(context);
    final libraryItem = provider.getLibraryItem(widget.rom.slug);
    final downloadPath = libraryItem?.filePath ?? "";
    final hasPath = downloadPath.isNotEmpty;

    bool getFileExists() {
      if (!hasPath || libraryItem == null) {
        return false;
      }

      final filePath = libraryItem.filePath!;
      if (Platform.isMacOS && filePath.endsWith(".app")) {
        return Directory(filePath).existsSync();
      }
      return File(filePath).existsSync();
    }

    bool getFileCanBeExtracted() {
      if (!hasPath || libraryItem == null || !getFileExists()) {
        return false;
      }

      final fileExtension =
          SystemHelpers.getFileExtension(libraryItem.filePath!).toLowerCase();
      return VALID_COMPRESSED_EXTENSIONS.contains(fileExtension);
    }

    Future<void> pickRomPath() async {
      final file = await FileSystemService.showFilePicker();
      if (file == null || libraryItem == null) {
        return;
      }

      libraryItem.filePath = file;
      await provider.updateLibraryItem(libraryItem);
    }

    Future<void> removeRomPath() async {
      if (libraryItem == null) {
        return;
      }

      libraryItem.filePath = "";
      await provider.updateLibraryItem(libraryItem);
    }

    Future<void> updateOverrideEmulator(String value) async {
      if (libraryItem == null) {
        return;
      }

      libraryItem.overrideEmulator = value;
      await provider.updateLibraryItem(libraryItem);
    }

    Future<void> updateLaunchParameters(String value) async {
      if (libraryItem == null) {
        return;
      }

      libraryItem.openParams = value;
      await provider.updateLibraryItem(libraryItem);
    }

    void handleOpenFolder() {
      FileSystemService.openFileFolder(libraryItem?.filePath ?? "");
    }

    Future<void> handleExtractRom() async {
      if (libraryItem == null) {
        return;
      }

      await RomService.extractRom(libraryItem);
    }

    Future<void> removeFromLibrary() async {
      await AlertsService.showAlert(
        context,
        "Remove from library",
        "Are you sure you want to remove this game from your library? all the game settings will be removed as well (No files will be deleted)",
        callback: () async {
          await provider.removeLibraryItem(widget.rom.slug);
          Navigator.of(context).pop();
        },
      );
    }

    Future<void> pickTime() async {
      if (libraryItem == null) {
        return;
      }

      showDialog<int>(
        context: context,
        builder: (context) => DurationPickerDialog(
          title: "Select Played Time",
          initialMinutes: libraryItem.playTimeMins.toInt(),
          onSubmit: (minutes) {
            libraryItem.playTimeMins = minutes.toDouble();
            provider.updateLibraryItem(libraryItem);
          },
        ),
      );
    }

    Future<void> restoreTime() async {
      if (libraryItem == null) {
        return;
      }

      libraryItem.playTimeMins = 0;
      await provider.updateLibraryItem(libraryItem);
    }

    Future<void> deleteRomFile() async {
      await AlertsService.showAlert(
        context,
        "Remove game file",
        "Are you sure you want to remove this game from your computer? This action cannot be undone.",
        callback: () async {
          final loader = AlertsService.showLoadingAlert(
            navigatorContext!,
            "Deleting",
            "Deleting game files...",
          );

          final filePath = libraryItem?.filePath;
          if (libraryItem != null && filePath != null && filePath.isNotEmpty) {
            final deleted = await RomService.deleteRomFiles(libraryItem);
            if (deleted) {
              libraryItem.filePath = "";
              await provider.updateLibraryItem(libraryItem);
            } else {
              loader.close();
              AlertsService.showErrorSnackbar(
                "Failed to delete Game files. It may have already been removed or is inaccessible.",
              );
              return;
            }
          }

          loader.close();
        },
      );
    }

    return AlertDialog(
      title: Text('Game Settings'),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      contentPadding: const EdgeInsets.all(10.0),
      content: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DialogSectionItem(
                padding: EdgeInsets.only(bottom: 0),
                title: "Rom path",
                content: Text(
                    downloadPath.isEmpty ? "Not downloaded" : downloadPath),
                icon: Icons.description,
                actions: [
                  if (downloadPath.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: removeRomPath,
                    ),
                  IconButton(
                    icon: Icon(Icons.file_open),
                    onPressed: pickRomPath,
                  ),
                ],
              ),
              if (downloadPath.isNotEmpty) ...[
                if (!getFileExists())
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Text(
                      "The file cannot be found on disk",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: handleOpenFolder,
                        label: Text("Open Folder"),
                        icon: Icon(Icons.folder_open),
                      ),
                      if (getFileCanBeExtracted())
                        TextButton.icon(
                          onPressed: handleExtractRom,
                          label: Text("Extract Rom"),
                          icon: Icon(Icons.folder_zip),
                        ),
                    ],
                  ),
                SizedBox(height: 10),
              ],
              EmulatorLaunchSettingsFields(
                console: widget.rom.console,
                binaryController: overrideEmulatorController,
                launchParametersController: launchParametersController,
                emulatorSetting: defaultEmulatorSetting,
                binaryTitle: "Emulator override",
                binaryHintText: "Default emulator",
                binaryHelperText:
                    "Override the console emulator for this game only. Leave it empty to keep using the console default.",
                launchParametersTitle: "Launch parameters",
                launchParametersHintText: "Custom launch parameters",
                launchParametersHelperText:
                    "Parameters flags used when launching the ROM. These are appended on top of the console-level emulator parameters.",
                enableBinaryEditing: FileSystemService.isDesktop,
                showLaunchParameters: FileSystemService.isDesktop,
                onBinaryChanged: updateOverrideEmulator,
                onLaunchParametersChanged: updateLaunchParameters,
              ),
              DialogSectionItem(
                title: "Time played",
                content: Text(TimeHelpers.formatMinutes(
                    libraryItem?.playTimeMins.toInt() ?? 0)),
                icon: Icons.access_time,
                actions: [
                  if ((libraryItem?.playTimeMins.toInt() ?? 0) != 0)
                    IconButton(
                      icon: Icon(Icons.settings_backup_restore),
                      onPressed: restoreTime,
                    ),
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: pickTime,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  "Danger Zone",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.redAccent,
                  ),
                ),
              ),
              _DangerSettingItem(
                title: "Remove from library",
                enabled: true,
                content: Text(
                    "This will delete configuration and metadata. The file will remain on disk"),
                icon: Icons.dangerous,
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: Colors.redAccent,
                    ),
                    onPressed: removeFromLibrary,
                  ),
                ],
              ),
              _DangerSettingItem(
                title: "Delete files",
                enabled: hasPath,
                content: Text(
                    "Permanently delete the file from storage. The library entry will not be removed."),
                icon: Icons.dangerous,
                actions: hasPath
                    ? [
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: deleteRomFile,
                        ),
                      ]
                    : [],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }

  Future<void> _loadDefaultEmulatorSetting() async {
    if (db == null) {
      return;
    }

    final setting = await EmulatorSettingsDao(db!).get(widget.rom.console);
    if (!mounted) {
      return;
    }

    setState(() {
      defaultEmulatorSetting = setting;
    });
  }
}

class _DangerSettingItem extends StatelessWidget {
  final String title;
  final Widget content;
  final IconData icon;
  final List<IconButton> actions;
  final bool enabled;

  const _DangerSettingItem({
    required this.title,
    required this.enabled,
    required this.content,
    required this.icon,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: enabled ? Colors.redAccent : Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: enabled ? Colors.redAccent : Colors.grey,
          ),
        ),
        subtitle: Opacity(opacity: 0.6, child: content),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: actions,
        ),
      ),
    );
  }
}
