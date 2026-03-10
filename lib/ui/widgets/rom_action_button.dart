import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/download_spinner.dart';
import 'package:yamata_launcher/ui/widgets/rom_download_sources_dialog/rom_download_sources_dialog.dart';
import 'package:yamata_launcher/services/download_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:provider/provider.dart';
import 'package:toast/toast.dart';

import '../../models/download_source_rom.dart';
import '../../services/alerts_service.dart';

enum RomActionButtonSize { small, large, medium }

class FileExistCache {
  static final Map<String, bool> _cache = {};

  static bool? get(String path) => _cache[path];
  static void invalidate(String path) => _cache.remove(path);

  static void set(String path, bool exists) {
    _cache[path] = exists;
  }
}

class RomActionButton extends StatefulWidget {
  final RomInfo rom;
  final RomActionButtonSize size;

  const RomActionButton(this.rom,
      {super.key, this.size = RomActionButtonSize.medium});

  @override
  State<RomActionButton> createState() => _RomActionButtonState();
}

class _RomActionButtonState extends State<RomActionButton> {
  @override
  Widget build(BuildContext context) {
    final provider = DownloadProvider.of(context);
    final libraryProvider = Provider.of<LibraryProvider>(context);
    final downloadSourcesProvider =
        Provider.of<DownloadSourcesProvider>(context);

    final rom = widget.rom;

    final libraryItem = libraryProvider.getLibraryItem(rom.slug);

    final isCompilingSource =
        downloadSourcesProvider.isRomCompilingDownloadSources(rom.slug);

    final isDownloading = provider.isRomDownloading(rom);
    final isPlaying = libraryProvider.isGameRunning(rom.slug);
    final isReadyToPlay = libraryProvider.isRomReadyToPlay(rom.slug);
    final hasDownloadSources =
        downloadSourcesProvider.getRomSources(rom.slug).isNotEmpty;
    final downloadInfo = provider.getDownloadInfo(rom);
    final isPaused = downloadInfo?.isPaused == true;
    final isExtracting = downloadInfo?.isExtracting == true;
    bool getFileIsCompressed() {
      if (libraryItem?.filePath == null) return false;
      final filePath = libraryItem!.filePath!;
      return VALID_COMPRESSED_EXTENSIONS
          .any((ext) => filePath.toLowerCase().endsWith(ext));
    }

    handleUpdateRomInLibrary(String filePath) async {
      final libraryProvider =
          Provider.of<LibraryProvider>(context, listen: false);
      final libraryItem = libraryProvider.getLibraryItem(widget.rom.slug);

      if (libraryItem == null) return;
      libraryItem.filePath = filePath;
      await libraryProvider.updateLibraryItem(libraryItem);
    }

    handleDownloadRom() async {
      final result = await showDialog<RomDownloadSourcesDialogResult>(
        context: context,
        builder: (_) => RomDownloadSourcesDialog(rom: widget.rom),
      );
      if (result == null) return;
      await libraryProvider.addRomToLibrary(widget.rom);
      DownloadService.downloadRom(widget.rom, result.rom,
          shouldExtract: result.extractAfterDownload);
      AlertsService.showSnackbar("Download started", duration: 3);
    }

    Future<void> handleCancelDownload() async {
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
        if (downloadInfo == null) return;
        if (downloadInfo.isExtracting) {
          return await handleCancelDownload();
        }

        await Provider.of<DownloadProvider>(context, listen: false)
            .pauseDownload(downloadInfo);
        AlertsService.showSnackbar("Download Paused");
        return;
      }
      if (isPaused) {
        if (downloadInfo == null) return;
        await DownloadService.continueDownload(downloadInfo);
        AlertsService.showSnackbar("Resuming Download...");
        return;
      }
      if (isReadyToPlay && libraryItem?.doesExists == false) {
        AlertsService.showAlert(navigatorContext!, "File not found",
            "Rom file not found. Please re-download the rom or locate the file.",
            acceptTitle: "Locate", callback: () async {
          var file = await FileSystemService.showFilePicker();
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
        if (getFileIsCompressed()) {
          await RomService.extractRom(libraryItem);
          return;
        }
        EmulatorService.openRom(libraryItem);
        AlertsService.showSnackbar("Rom launched");
        return;
      }
      if (hasDownloadSources) {
        handleDownloadRom();
      }
    }

    var isVerifying = isReadyToPlay && libraryItem?.doesExists == null;

    final fileExists = libraryItem?.doesExists ?? false;

    double horizontalPadding;
    double verticalPadding;
    double iconSize;
    double fontSize;
    double spacing;

    switch (widget.size) {
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
      default:
        horizontalPadding = 15;
        verticalPadding = 16;
        iconSize = 24;
        fontSize = 13;
        spacing = 3;
    }

    final padding = EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: verticalPadding,
    );

    IconData icon = Icons.cloud_off_rounded;
    String text = "No downloads";
    if (isPlaying) {
      icon = FileSystemService.isDesktop ? Icons.close : Icons.videogame_asset;
      text = FileSystemService.isDesktop ? "Close" : "Playing";
    } else if (isDownloading) {
      if (isExtracting) {
        icon = Icons.stop;
        text = "Cancel";
      } else {
        icon = Icons.pause;
        text = "Pause";
      }
    } else if (isPaused) {
      icon = Icons.play_arrow;
      text = "Resume";
    } else if (isReadyToPlay) {
      if (fileExists) {
        if (getFileIsCompressed()) {
          icon = Icons.folder_zip;
          text = "Extract";
        } else {
          icon = Icons.play_arrow_outlined;
          text = "Play";
        }
      } else {
        icon = Icons.folder_off;
        text = "File not found";
      }
    } else if ((isCompilingSource || isVerifying)) {
      icon = Icons.hourglass_top;
      text = "Loading...";
    } else if (hasDownloadSources) {
      icon = Icons.cloud_download_outlined;
      text = "Download";
    }

    return Row(children: [
      ElevatedButton.icon(
        icon: Icon(icon, size: iconSize),
        label: Text(
          text,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(padding: padding),
        onPressed: (hasDownloadSources ||
                    isReadyToPlay ||
                    isDownloading ||
                    isPaused) ||
                (isPlaying && FileSystemService.isDesktop)
            ? handleButtonPress
            : null,
      ),
      if ((isDownloading && !isExtracting) || isPaused) ...[
        SizedBox(width: spacing),
        IconButton(
            onPressed: handleCancelDownload,
            icon: Icon(Icons.close, size: iconSize)),
      ]
    ]);
  }
}
