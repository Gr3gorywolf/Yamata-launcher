import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/download_service.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/rom_download_sources_dialog/rom_download_sources_dialog.dart';
import 'package:yamata_launcher/ui/widgets/rom_download_sources_dialog/rom_download_sources_dialog_confirm_dialog.dart';
import 'package:yamata_launcher/ui/widgets/rom_metadata_form.dart';
import 'package:yamata_launcher/ui/widgets/rom_thumbnail.dart';

class NewDownloadForm extends StatefulWidget {
  final String? initialUrl;
  const NewDownloadForm({super.key, this.initialUrl});

  @override
  State<NewDownloadForm> createState() => _NewDownloadFormState();
}

class _NewDownloadFormState extends State<NewDownloadForm> {
  RomInfo? scrapedRomInfo;
  String? downloadLink;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      downloadLink = widget.initialUrl;
    }
  }

  bool get isValid {
    return scrapedRomInfo != null &&
        downloadLink != null &&
        downloadLink!.trim().isNotEmpty;
  }

  void handleStartDownload() async {
    if (scrapedRomInfo == null || downloadLink == null) return;
    var downloadSourceRom = DownloadSourceRom(
      uris: [downloadLink!],
      title: scrapedRomInfo!.name,
      console: scrapedRomInfo!.console,
    );
    var result = await showDialog<RomDownloadSourcesDialogResult?>(
      context: context,
      builder: (_) => DownloadSourcesDialogConfirmDialog(
        item: RomDownloadSourceItem(
          rom: downloadSourceRom,
          sourceTitle: "Manual download",
        ),
      ),
    );

    if (result != null) {
      var libraryItem = RomLibraryItem(
        rom: scrapedRomInfo!,
        manualDownload: downloadSourceRom,
        addedAt: DateTime.now(),
      );
      await Provider.of<LibraryProvider>(context, listen: false)
          .addLibraryItem(libraryItem);
      DownloadService.downloadRom(scrapedRomInfo!, result.rom,
          shouldExtract: true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Add new download"),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      contentPadding: const EdgeInsets.all(10.0),
      content: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450, minWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DialogSectionItem(
                title: "Game metadata",
                icon: Icons.title,
                helperText:
                    "This is the metadata that will be used to identify the new downloaded game.",
                actions: [
                  IconButton(
                    icon: Icon(Icons.travel_explore),
                    onPressed: () {
                      RomMetadataForm.show(context, (info, path) {
                        setState(() {
                          scrapedRomInfo = info;
                        });
                      }, canEditPath: false);
                    },
                  ),
                ],
                content: scrapedRomInfo != null
                    ? Row(
                        children: [
                          RomThumbnail(
                            scrapedRomInfo!,
                            height: 64,
                            width: 64,
                          ),
                          SizedBox(width: 10),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(scrapedRomInfo?.name ?? "No title found"),
                              SizedBox(width: 10),
                              Opacity(
                                opacity: 0.6,
                                child: Text(ConsoleService.getConsoleFromName(
                                            scrapedRomInfo?.console)
                                        ?.name ??
                                    "Unknown console"),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Text("No rom info scraped yet"),
              ),
              DialogSectionItem(
                title: "Download URL",
                icon: Icons.link,
                actions: [],
                content: TextField(
                  onChanged: (value) => setState(() => downloadLink = value),
                  maxLines: 3,
                  minLines: 3,
                  controller: TextEditingController(text: downloadLink),
                  decoration: _inputDecoration(
                    hintText: "Enter the URL to download the game from",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: isValid ? handleStartDownload : null,
          child: const Text('Add download'),
        )
      ],
    );
  }
}

InputDecoration _inputDecoration({required String hintText}) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  );
}
