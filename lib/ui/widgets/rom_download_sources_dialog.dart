import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/main.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';

class RomDownloadSourcesDialog extends StatelessWidget {
  final RomInfo rom;
  final bool showRomLocate;

  const RomDownloadSourcesDialog({
    Key? key,
    required this.rom,
    this.showRomLocate = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadSourcesProvider>();

    final List<DownloadSourceWithDownloads> results =
        provider.findRomSourcesWithDownloads(rom);
    final List<_Result> filteredResults = [];
    for (final source in results) {
      for (final sourceDownload in source.downloads!) {
        filteredResults.add(_Result(
          rom: sourceDownload,
          sourceTitle: source.sourceInfo!.title,
        ));
      }
    }

    locateAndAddToLibrary() async {
      final file = await FileSystemService.locateFile();
      if (file == null) return;
      var provider = Provider.of<LibraryProvider>(context, listen: false);
      var item = provider.addRomToLibrary(rom);
      item.filePath = file;
      await provider.updateLibraryItem(item);
      await Navigator.of(context).maybePop();
      AlertsService.showSnackbar("Rom file located successfully");
    }

    Future handleDownloadSourceSelected(DownloadSourceRom sourceRom) async {
      var loading = AlertsService.showLoadingAlert(
          context,
          "Preparing download...",
          "Retrieving download link information please wait...");
      var link =
          await DownloadSourcesRepository().extractDownloadSourceUrl(sourceRom);
      loading.close();
      if (link == null || link.isEmpty) {
        AlertsService.showErrorSnackbar(
            "Could not extract download link for ${sourceRom.title}");
        return;
      }
      final newSource = DownloadSourceRom(
          console: sourceRom.console,
          title: sourceRom.title,
          fileSize: sourceRom.fileSize,
          uploadDate: sourceRom.uploadDate,
          uris: [link],
          fileIndex: sourceRom.fileIndex,
          filePath: sourceRom.filePath,
          title_clean: sourceRom.title_clean);
      Navigator.pop(context, newSource);
    }

    return AlertDialog(
      title: Text("Available download options"),
      content: SizedBox(
        width: 420,
        height: 420,
        child: results.isEmpty
            ? const Center(
                child: Text(
                  'No matching ROMs found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: filteredResults.length,
                itemBuilder: (_, index) {
                  final item = filteredResults[index];
                  return ListTile(
                    leading: const Icon(Icons.gamepad),
                    title: Text(
                      item.rom.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Opacity(
                      opacity: 0.7,
                      child: Text(
                        '${item.sourceTitle} • ${item.rom.fileSize}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    onTap: () {
                      handleDownloadSourceSelected(item.rom);
                    },
                  );
                },
              ),
      ),
      actions: [
        if (showRomLocate)
          TextButton(
            onPressed: locateAndAddToLibrary,
            child: const Text('Locate rom file'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _Result {
  final DownloadSourceRom rom;
  final String? sourceTitle;

  _Result({
    required this.rom,
    required this.sourceTitle,
  });
}
