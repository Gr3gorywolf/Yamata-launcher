import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/download_spinner.dart';
import 'package:yamata_launcher/ui/widgets/rom_download_sources_dialog.dart';
import 'package:yamata_launcher/services/download_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:provider/provider.dart';
import 'package:toast/toast.dart';

import '../../models/download_source_rom.dart';
import '../../services/alerts_service.dart';

enum RomActionButtonSize { small, large, medium }

class RomActionButton extends StatelessWidget {
  RomInfo rom;
  RomActionButtonSize size;
  RomActionButton(this.rom, {this.size = RomActionButtonSize.medium});
  @override
  Widget build(BuildContext context) {
    var provider = DownloadProvider.of(context);
    var libraryProvider = Provider.of<LibraryProvider>(context);
    var downloadSourcesProvider = Provider.of<DownloadSourcesProvider>(context);

    var libraryItem = libraryProvider.getLibraryItem(rom.slug);

    var isCompilingSource =
        downloadSourcesProvider.isRomCompilingDownloadSources(rom.slug);

    var isDownloading = provider.isRomDownloading(rom);
    var isPlaying = libraryProvider.isGameRunning(rom.slug);
    var isReadyToPlay = libraryProvider.isRomReadyToPlay(rom.slug);
    var hasDownloadSources =
        downloadSourcesProvider.getRomSources(rom.slug).isNotEmpty;

    bool getFileExist() {
      if (isReadyToPlay) {
        var filePath = libraryItem!.filePath!;
        if (Platform.isMacOS && filePath.endsWith(".app")) {
          return Directory(filePath).existsSync();
        }
        return File(filePath).existsSync();
      }
      return false;
    }

    handleUpdateRomInLibrary(String filePath) async {
      if (libraryItem == null) return;
      libraryItem.filePath = filePath;
      await libraryProvider.updateLibraryItem(libraryItem);
    }

    handleDownloadRom() async {
      final romSource = await showDialog<DownloadSourceRom>(
        context: context,
        builder: (_) => RomDownloadSourcesDialog(rom: rom),
      );

      if (romSource == null) return;

      await libraryProvider.addRomToLibrary(rom);

      DownloadService.downloadRom(rom, romSource);
      AlertsService.showSnackbar("Download started", duration: 3);
    }

    Future<void> handleButtonPress() async {
      if (isPlaying) {
        if (FileSystemService.isDesktop) {
          EmulatorService.closeRunningRom(rom.slug);
          AlertsService.showSnackbar("Closing ${rom.name}...");
        }

        return;
      }

      if (isDownloading) {
        var downloadInfo = provider.getDownloadInfo(rom);
        if (downloadInfo == null) return;
        AlertsService.showAlert(
          navigatorContext!,
          "Warning",
          "You are sure you want to cancel this ${downloadInfo.isExtracting ? "extraction" : "download"}?",
          acceptTitle: "Yes",
          callback: () {
            Provider.of<DownloadProvider>(context, listen: false)
                .abortDownload(downloadInfo);
            AlertsService.showSnackbar(
                "${downloadInfo.isExtracting ? "Extraction" : "Download"} cancelled");
          },
          cancelable: true,
        );
        return;
      }

      if (isReadyToPlay && !getFileExist()) {
        AlertsService.showAlert(navigatorContext!, "File not found",
            "Rom file not found. Please re-download the rom or locate the file.",
            acceptTitle: "Locate", callback: () async {
          var file = await FileSystemService.locateFile();
          if (file != null) {
            await handleUpdateRomInLibrary(file);
            await Navigator.of(context).maybePop();
            AlertsService.showSnackbar("Rom file located successfully");
          }
        },
            cancelable: true,
            additionalAction: hasDownloadSources
                ? TextButton(
                    onPressed: () async {
                      await Navigator.of(context, rootNavigator: true)
                          .maybePop();
                      handleDownloadRom();
                    },
                    child: Text("Re-download"))
                : null);
        return;
      }

      if (isReadyToPlay && libraryItem != null) {
        EmulatorService.openRom(libraryItem);
        AlertsService.showSnackbar("Rom launched");
        return;
      }

      if (hasDownloadSources) {
        handleDownloadRom();
      }
    }

    double horizontalPadding;
    double verticalPadding;
    double iconSize;
    double fontSize;
    double spacing;

    switch (size) {
      case RomActionButtonSize.small:
        horizontalPadding = 10;
        verticalPadding = 10;
        iconSize = 16;
        fontSize = 11;
        spacing = 2;
        break;
      case RomActionButtonSize.large:
        horizontalPadding = 20;
        verticalPadding = 20;
        iconSize = 28;
        fontSize = 16;
        spacing = 5;
        break;
      case RomActionButtonSize.medium:
      default:
        horizontalPadding = 15;
        verticalPadding = 16;
        iconSize = 24;
        fontSize = 13;
        spacing = 3;
        break;
    }

    final padding = EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: verticalPadding,
    );

    var icon = Icons.cloud_off_rounded;
    var text = "No downloads";

    if (isPlaying) {
      icon = FileSystemService.isDesktop ? Icons.close : Icons.videogame_asset;
      text = FileSystemService.isDesktop ? "Close" : "Playing";
    } else if (isDownloading) {
      icon = Icons.stop;
      text = "Cancel";
    } else if (isReadyToPlay) {
      if (getFileExist()) {
        icon = Icons.play_arrow_outlined;
        text = "Play";
      } else {
        icon = Icons.folder_off;
        text = "File not found";
      }
    } else if (hasDownloadSources) {
      icon = Icons.cloud_download_outlined;
      text = "Download";
    } else if (isCompilingSource) {
      icon = Icons.hourglass_top;
      text = "Loading...";
    }

    return ElevatedButton.icon(
      icon: Icon(icon, size: iconSize),
      label: Text(
        text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(padding: padding),
      onPressed: (hasDownloadSources || isReadyToPlay || isDownloading) ||
              (isPlaying && FileSystemService.isDesktop)
          ? handleButtonPress
          : null,
    );
  }
}
