import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/hoster_info.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/rom_download_sources_dialog/rom_download_sources_dialog_confirm_dialog.dart';
import 'package:yamata_launcher/ui/widgets/status_tag.dart';

class RomDownloadSourcesDialog extends StatefulWidget {
  final RomInfo rom;
  final bool showRomLocate;

  const RomDownloadSourcesDialog({
    Key? key,
    required this.rom,
    this.showRomLocate = true,
  }) : super(key: key);

  @override
  State<RomDownloadSourcesDialog> createState() =>
      _RomDownloadSourcesDialogState();
}

class _RomDownloadSourcesDialogState extends State<RomDownloadSourcesDialog> {
  Map<String, HosterInfo> urlHosters = {};
  List<RomDownloadSourceItem> results = [];

  String selectedSource = "All";

  locateAndAddToLibrary() async {
    final file = await FileSystemService.showFilePicker();
    if (file == null) return;
    var provider = Provider.of<LibraryProvider>(context, listen: false);
    var item = provider.addRomToLibrary(widget.rom);
    item.filePath = file;
    await provider.updateLibraryItem(item);
    await Navigator.of(context).maybePop();
    AlertsService.showSnackbar("Rom file located successfully");
  }

  fetchSources() {
    var provider = Provider.of<DownloadSourcesProvider>(context, listen: false);
    List<DownloadSourceWithDownloads> sourcesWithDownloads =
        provider.findRomSourcesWithDownloads(widget.rom);

    final List<RomDownloadSourceItem> filteredResults = [];

    for (final source in sourcesWithDownloads) {
      for (final sourceDownload in source.downloads) {
        filteredResults.add(RomDownloadSourceItem(
          rom: sourceDownload,
          sourceTitle: source.sourceInfo.title,
        ));
      }
    }

    results = filteredResults;
    setState(() {});
  }

  Set<String> getAvailableSources() {
    return results.map((e) => e.sourceTitle ?? "Unknown").toSet();
  }

  List<RomDownloadSourceItem> getFilteredResults() {
    if (selectedSource == "All") return results;

    return results.where((item) => item.sourceTitle == selectedSource).toList();
  }

  handleOpenConfirmDialog(RomDownloadSourceItem item) async {
    var result = await showDialog<RomDownloadSourcesDialogResult?>(
      context: context,
      builder: (_) => DownloadSourcesDialogConfirmDialog(item: item),
    );

    if (result != null) {
      Navigator.pop(context, result);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchSources();
  }

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context);

    final filteredResults = getFilteredResults();

    return AlertDialog(
      title: const Text("Download Options"),
      content: Container(
        width: mediaQuery.size.width * 0.5,
        constraints: const BoxConstraints(
            maxWidth: 500, maxHeight: 600, minWidth: 420, minHeight: 320),
        child: results.isEmpty
            ? const Center(
                child: Text(
                  'No matching sources found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSource,
                    items: [
                      const DropdownMenuItem(
                        value: "All",
                        child: Text("All"),
                      ),
                      ...getAvailableSources().map(
                        (source) => DropdownMenuItem(
                          value: source,
                          child: Text(source),
                        ),
                      )
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedSource = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredResults.length,
                      itemBuilder: (_, index) {
                        final item = filteredResults[index];

                        final hosterNames = (item.rom.uris ?? [])
                            .map((uri) =>
                                DownloadSourcesRepository()
                                    .getDownloadSourceUrlHosterName(uri) ??
                                Uri.parse(uri).host)
                            .toSet();

                        return Card(
                          elevation: 0,
                          child: ListTile(
                            hoverColor: Colors.transparent,
                            title: Text(
                              item.rom.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Opacity(
                                  opacity: 0.7,
                                  child: Text(
                                    ' ${item.sourceTitle} • ${item.rom.fileSize ?? "--"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: hosterNames
                                      .map((name) => StatusTag(text: name))
                                      .toList(),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              handleOpenConfirmDialog(item);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        if (widget.showRomLocate)
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

class RomDownloadSourcesDialogResult {
  final DownloadSourceRom rom;
  final bool extractAfterDownload;

  RomDownloadSourcesDialogResult({
    required this.rom,
    required this.extractAfterDownload,
  });
}

class RomDownloadSourceItem {
  final DownloadSourceRom rom;
  final String? sourceTitle;

  RomDownloadSourceItem({
    required this.rom,
    required this.sourceTitle,
  });
}
