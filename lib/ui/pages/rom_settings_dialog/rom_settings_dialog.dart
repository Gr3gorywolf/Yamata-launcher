import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:device_apps/device_apps.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/native/intents_android_interface.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/widgets/app_selection_dialog.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/duration_picker_dialog.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';
import 'package:yamata_launcher/utils/time_helpers.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

class RomSettingsDialog extends StatelessWidget {
  final RomInfo rom;
  RomSettingsDialog({super.key, required this.rom});
  var launchParameters = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var provider = Provider.of<LibraryProvider>(context);
    var libraryItem = provider.getLibraryItem(rom.slug);
    var _downloadPath = libraryItem?.filePath ?? "";
    var overrideEmulator = libraryItem?.overrideEmulator ?? "";
    launchParameters.text = libraryItem?.openParams ?? "";
    var hasPath = _downloadPath.isNotEmpty;

    bool _getFileExist() {
      if (hasPath) {
        var filePath = libraryItem!.filePath!;
        if (Platform.isMacOS && filePath.endsWith(".app")) {
          return Directory(filePath).existsSync();
        }
        return File(filePath).existsSync();
      }
      return false;
    }

    _getFileCanBeExtracted() {
      if (!hasPath) return false;
      if (!_getFileExist()) return false;
      var fileExtension =
          SystemHelpers.getFileExtension(libraryItem!.filePath!).toLowerCase();
      return VALID_COMPRESSED_EXTENSIONS.contains(fileExtension);
    }

    _pickRomPath() async {
      var file = await FileSystemService.showFilePicker();
      if (file == null || libraryItem == null) return;
      libraryItem.filePath = file;
      await provider.updateLibraryItem(libraryItem);
    }

    _removeRomPath() async {
      if (libraryItem != null) {
        libraryItem.filePath = "";
        await provider.updateLibraryItem(libraryItem);
      }
    }

    _pickEmulatorBinary() async {
      if (Platform.isAndroid) {
        var consoleEmulators =
            EmulatorService.getEmulatorPackagesForConsole(rom.console);
        var result = await AppSelectionDialog.show(context,
            filteredApps: consoleEmulators);
        if (result != null && libraryItem != null) {
          libraryItem.overrideEmulator = result.packageName;
          await provider.updateLibraryItem(libraryItem);
        }
        return;
      }
      var validExtensions = VALID_EXECUTABLE_EXTENSIONS;
      String? selectedFilePath = null;
      try {
        FilePickerResult? selectedFile = await FilePicker.platform.pickFiles(
          dialogTitle: "Select Emulator Binary",
          type: FileType.custom,
          initialDirectory: Platform.isMacOS ? "/Applications" : null,
          allowedExtensions: validExtensions,
        );
        if (selectedFile != null) {
          selectedFilePath = selectedFile.files.single.path ?? "";
        }
      } catch (e) {
        print("Error selecting emulator binary: $e");
        var filePath = await FileSystemService.showFilePicker(
            allowedExtensions: validExtensions);
        if (filePath != null) {
          selectedFilePath = filePath;
        }
      }
      if (selectedFilePath == null || libraryItem == null) return;
      libraryItem.overrideEmulator = selectedFilePath;
      await provider.updateLibraryItem(libraryItem);
    }

    _restoreEmulator() async {
      if (libraryItem != null) {
        libraryItem.overrideEmulator = "";
        await provider.updateLibraryItem(libraryItem);
      }
    }

    _handleOpenFolder() async {
      FileSystemService.openFileFolder(libraryItem?.filePath ?? "");
    }

    _handleExtractRom() async {
      await RomService.extractRom(libraryItem!);
    }

    _removeFromLibrary() async {
      await AlertsService.showAlert(context, "Remove from library",
          "Are you sure you want to remove this game from your library? all the game settings will be removed as well (No files will be deleted)",
          callback: () async {
        await provider.removeLibraryItem(rom.slug);
        Navigator.of(context).pop();
      });
    }

    _pickTime() async {
      if (libraryItem != null) {
        showDialog<int>(
          context: context,
          builder: (context) => DurationPickerDialog(
            title: "Select Played Time",
            initialMinutes: libraryItem.playTimeMins?.toInt() ?? 0,
            onSubmit: (minutes) {
              libraryItem.playTimeMins = minutes.toDouble();
              provider.updateLibraryItem(libraryItem);
            },
          ),
        );
      }
    }

    _restoreTime() async {
      if (libraryItem != null) {
        libraryItem.playTimeMins = 0;
        await provider.updateLibraryItem(libraryItem);
      }
    }

    _deleteRomFile() async {
      await AlertsService.showAlert(context, "Remove game file",
          "Are you sure you want to remove this game from your computer? This action cannot be undone.",
          callback: () async {
        if (libraryItem != null && libraryItem.filePath!.isNotEmpty) {
          var deleted = await RomService.deleteRomFiles(libraryItem);
          if (deleted) {
            libraryItem.filePath = "";
            await provider.updateLibraryItem(libraryItem);
          } else {
            AlertsService.showErrorSnackbar(
                "Failed to delete Game files. It may have already been removed or is inaccessible.");
          }
        }
      });
    }

    return AlertDialog(
      title: Text('Game Settings'),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      contentPadding: const EdgeInsets.all(10.0),
      content: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(maxWidth: 400),
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DialogSectionItem(
                  padding: EdgeInsets.only(bottom: 0),
                  title: "Rom path",
                  content: Text(
                      _downloadPath.isEmpty ? "Not downloaded" : _downloadPath),
                  icon: Icons.description,
                  actions: [
                    ..._downloadPath.isEmpty
                        ? []
                        : [
                            IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: _removeRomPath),
                          ],
                    IconButton(
                        icon: Icon(Icons.file_open), onPressed: _pickRomPath)
                  ],
                ),
                ...!_downloadPath.isEmpty
                    ? [
                        !_getFileExist()
                            ? Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: Text("The file cannot be found on disk",
                                    style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.w500)),
                              )
                            : Row(
                                children: [
                                  TextButton.icon(
                                      onPressed: _handleOpenFolder,
                                      label: Text("Open Folder"),
                                      icon: Icon(Icons.folder_open)),
                                  if (_getFileCanBeExtracted())
                                    TextButton.icon(
                                        onPressed: _handleExtractRom,
                                        label: Text("Extract Rom"),
                                        icon: Icon(Icons.folder_zip)),
                                ],
                              ),
                        SizedBox(height: 10),
                      ]
                    : [],
                DialogSectionItem(
                  title: "Emulator override",
                  content: Text(overrideEmulator.isEmpty
                      ? "Default Emulator"
                      : overrideEmulator),
                  icon: Icons.videogame_asset,
                  actions: [
                    ...overrideEmulator.isEmpty
                        ? []
                        : [
                            IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: _restoreEmulator),
                          ],
                    IconButton(
                        icon: Icon(Icons.file_open),
                        onPressed: () => _pickEmulatorBinary()),
                  ],
                ),
                if (FileSystemService.isDesktop)
                  DialogSectionItem(
                    title: "Launch parameters",
                    helperText:
                        "Parameters flags used when launching the ROM (if supported by the emulator)",
                    content: TextField(
                      controller: launchParameters,
                      decoration: InputDecoration(
                        hintText: "Custom launch parameters",
                        helperMaxLines: 3,
                        helperStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (text) {
                        libraryItem?.openParams = text;
                        if (libraryItem != null) {
                          provider.updateLibraryItem(libraryItem);
                        }
                      },
                    ),
                    icon: Icons.terminal,
                    actions: [],
                  ),
                DialogSectionItem(
                  title: "Time played",
                  content: Text(TimeHelpers.formatMinutes(
                      libraryItem?.playTimeMins.toInt() ?? 0)),
                  icon: Icons.access_time,
                  actions: [
                    ...((libraryItem?.playTimeMins.toInt() ?? 0) == 0
                        ? []
                        : [
                            IconButton(
                                icon: Icon(Icons.settings_backup_restore),
                                onPressed: _restoreTime),
                          ]),
                    IconButton(
                        icon: Icon(Icons.edit), onPressed: () => _pickTime()),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text("Danger Zone",
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.redAccent)),
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
                          onPressed: _removeFromLibrary)
                    ]),
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
                                onPressed: _deleteRomFile)
                          ]
                        : []),
              ],
            ),
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
}

class _DangerSettingItem extends StatelessWidget {
  final String title;
  final Widget content;
  final IconData icon;
  final List<IconButton> actions;
  final bool enabled;

  const _DangerSettingItem(
      {required this.title,
      required this.enabled,
      required this.content,
      required this.icon,
      required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? Colors.redAccent : Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: ListTile(
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: enabled ? Colors.redAccent : Colors.grey)),
          subtitle: Opacity(opacity: 0.6, child: content),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: actions,
          ),
        ));
  }
}
