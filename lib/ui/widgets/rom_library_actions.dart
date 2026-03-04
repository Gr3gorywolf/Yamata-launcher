import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/download_history_item.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/download_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/native/intents_android_interface.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/pages/rom_settings_dialog/rom_settings_dialog.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/ui/widgets/rom_download_sources_dialog/rom_download_sources_dialog.dart';

import '../../utils/system_helpers.dart';

enum RomLibraryActionSize { small, medium, large }

enum _RomMenuAction {
  settings,
  downloadExtra,
  extractRom,
  openRomFolder,
  removeFromLibrary
}

class RomLibraryActions extends StatelessWidget {
  final RomInfo rom;
  final DownloadHistoryItem? downloadHistoryItem;
  RomLibraryActionSize? size = RomLibraryActionSize.medium;

  RomLibraryActions(
      {super.key, required this.rom, this.size, this.downloadHistoryItem});

  handleExtractRom(RomLibraryItem rom) async {
    RomService.extractRom(rom);
  }

  @override
  Widget build(BuildContext context) {
    var libraryProvider = Provider.of<LibraryProvider>(context);
    var downloadSourcesProvider = Provider.of<DownloadSourcesProvider>(context);
    var downloadProvider = Provider.of<DownloadProvider>(context);
    var libraryItem = libraryProvider.getLibraryItem(rom.slug);
    var isFavorite = (libraryItem?.isFavorite ?? false) == true;
    var filePath = libraryItem?.filePath ?? "";
    var hasFile = filePath.isNotEmpty;
    double? minimumSize = 35;
    double? iconSize = 22;
    double spacing = 8;
    double contentWidth = 35;

    if (size == RomLibraryActionSize.small) {
      minimumSize = 30;
      iconSize = 18;
      contentWidth = 30;
    } else if (size == RomLibraryActionSize.large) {
      minimumSize = 40;
      iconSize = 26;
      contentWidth = 40;
    }

    getFileCanBeExtracted() {
      if (!hasFile) return false;
      if (!File(filePath).existsSync()) return false;
      var fileExtension =
          SystemHelpers.getFileExtension(filePath).toLowerCase();
      return VALID_COMPRESSED_EXTENSIONS.contains(fileExtension);
    }

    handleRemoveFromLibrary() async {
      if (libraryItem == null) return;

      await AlertsService.showAlert(context, "Remove from library",
          "Are you sure you want to remove this ROM from your library? all the rom settings will be removed as well (No files will be deleted)",
          callback: () async {
        await libraryProvider.removeLibraryItem(libraryItem.rom.slug);
        AlertsService.showSnackbar("Rom removed from library");
      });
    }

    handleToggleLike() {
      if (libraryItem == null) return;
      var newLibraryItem = libraryItem;
      newLibraryItem.isFavorite = !isFavorite;
      libraryProvider.updateLibraryItem(newLibraryItem);
      AlertsService.showSnackbar(newLibraryItem.isFavorite
          ? "Rom added to favorites"
          : "Rom removed from favorites");
    }

    handleAddToLibrary() {
      AlertsService.showSnackbar("Rom added to library");
      libraryProvider.addRomToLibrary(rom);
    }

    handleOpenConfigurations() {
      showDialog(
          context: context,
          builder: (dialog) {
            return RomSettingsDialog(rom: rom);
          });
    }

    handleDownloadExtraContent() async {
      final result = await showDialog<RomDownloadSourcesDialogResult>(
        context: context,
        builder: (_) => RomDownloadSourcesDialog(
          rom: rom,
          showRomLocate: false,
        ),
      );

      if (result == null) return;
      DownloadService.downloadRom(rom, result.rom,
          isExtraContent: true, shouldExtract: result.extractAfterDownload);
      AlertsService.showSnackbar("Download started", duration: 3);
    }

    iconButtonStyle() {
      return IconButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
          padding: EdgeInsets.all(4),
          minimumSize:
              minimumSize != null ? Size(minimumSize!, minimumSize!) : null);
    }

    if (downloadHistoryItem != null) {
      return IconButton(
        iconSize: iconSize,
        style: iconButtonStyle(),
        icon: Icon(Icons.folder),
        onPressed: () {
          FileSystemService.openFileFolder(downloadHistoryItem!.filePath ?? "");
        },
        color: Colors.grey,
      );
    }

    if (libraryItem == null) {
      return IconButton(
        iconSize: iconSize,
        style: iconButtonStyle(),
        icon: Icon(Icons.library_add),
        onPressed: handleAddToLibrary,
        color: Colors.grey,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: contentWidth,
          child: IconButton(
            iconSize: iconSize,
            style: iconButtonStyle(),
            icon: Icon(
              libraryItem.isFavorite == true ? Icons.star : Icons.star_border,
              color: isFavorite ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () {
              handleToggleLike();
            },
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            color: Colors.grey,
          ),
        ),
        SizedBox(
          width: spacing,
        ),
        Container(
          width: contentWidth,
          child: PopupMenuButton<_RomMenuAction>(
            iconSize: iconSize,
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            tooltip: "More",
            color: Theme.of(context).colorScheme.inverseSurface,
            offset: const Offset(0, 30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            style: iconButtonStyle(),
            onSelected: (action) {
              switch (action) {
                case _RomMenuAction.settings:
                  handleOpenConfigurations();
                  break;
                case _RomMenuAction.downloadExtra:
                  handleDownloadExtraContent();
                  break;
                case _RomMenuAction.extractRom:
                  handleExtractRom(libraryItem);
                case _RomMenuAction.openRomFolder:
                  FileSystemService.openFileFolder(libraryItem.filePath ?? "");
                case _RomMenuAction.removeFromLibrary:
                  handleRemoveFromLibrary();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_RomMenuAction>(
                  value: _RomMenuAction.settings,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 20),
                      SizedBox(width: 10),
                      Text("Game settings"),
                    ],
                  )),
              if (libraryItem.filePath != null &&
                  libraryItem.filePath!.isNotEmpty &&
                  downloadSourcesProvider.getRomSources(rom.slug).isNotEmpty)
                PopupMenuItem<_RomMenuAction>(
                  value: _RomMenuAction.downloadExtra,
                  enabled: !downloadProvider.isRomDownloading(rom),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, size: 20),
                      SizedBox(width: 10),
                      Text("Download extra content"),
                    ],
                  ),
                ),
              if (hasFile)
                PopupMenuItem<_RomMenuAction>(
                  value: _RomMenuAction.openRomFolder,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder, size: 20),
                      SizedBox(width: 10),
                      Text("Open folder"),
                    ],
                  ),
                ),
              if (getFileCanBeExtracted())
                PopupMenuItem<_RomMenuAction>(
                  value: _RomMenuAction.extractRom,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_zip, size: 20),
                      SizedBox(width: 10),
                      Text("Extract Rom"),
                    ],
                  ),
                ),
              PopupMenuItem<_RomMenuAction>(
                value: _RomMenuAction.removeFromLibrary,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Remove from library",
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
