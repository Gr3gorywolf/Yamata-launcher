import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/main.dart';
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
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class DownloadSourceHosterSelectDialog extends StatefulWidget {
  List<String> uris;

  DownloadSourceHosterSelectDialog({
    Key? key,
    required this.uris,
  }) : super(key: key);

  @override
  State<DownloadSourceHosterSelectDialog> createState() =>
      _DownloadSourceHosterSelectDialogState();
}

class _DownloadSourceHosterSelectDialogState
    extends State<DownloadSourceHosterSelectDialog> {
  List<HosterInfo> hosters = [];

  Future<void> loadHosters() async {
    for (final uri in widget.uris) {
      var hosterName =
          DownloadSourcesRepository().getDownloadSourceUrlHosterName(uri);
      if (hosterName != null) {
        hosters.add(HosterInfo(
            uri: uri,
            domain: hosterName,
            isDirect: false,
            canExtractLink: true));
        setState(() {});
        continue;
      }
      DownloadSourcesRepository().isDirectDownload(uri).then((isDirect) {
        final domain = "${isDirect ? "Direct download " : ""}" +
            StringHelper.getDomainName(uri);
        hosters.add(HosterInfo(
            uri: uri,
            domain: domain,
            isDirect: isDirect,
            canExtractLink: isDirect));
        setState(() {});
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadHosters();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Select your preferred download hoster"),
      content: SizedBox(
        width: 300,
        height: 300,
        child: hosters.isEmpty
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  if (hosters.length != widget.uris.length)
                    LinearProgressIndicator(
                      value: null,
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: hosters.length,
                      itemBuilder: (_, index) {
                        final item = hosters[index];
                        return ListTile(
                          leading: Icon(
                            Icons.dns,
                            color:
                                item.canExtractLink ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            item.domain,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Opacity(
                            opacity: 0.7,
                            child: Text(
                              item.canExtractLink
                                  ? "Compatible source"
                                  : "Incompatible source",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context, item);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
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
