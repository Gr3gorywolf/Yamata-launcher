import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/main.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/exceptions/download_require_manual_exception.dart';
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
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/ui/widgets/download_link_web_extractor/download_link_web_extractor.dart';
import 'package:yamata_launcher/ui/widgets/download_source_hoster_select_dialog.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

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
  List<_Result> results = [];
  var extractAfterDownload = false;

  Future fetchSingleSourcesHosters() async {
    for (final result in results) {
      if (result.rom.uris!.length == 1) {
        var uri = result.rom.uris!.first;
        var hosterName =
            DownloadSourcesRepository().getDownloadSourceUrlHosterName(uri);
        if (hosterName != null) {
          urlHosters[uri] = HosterInfo(
              uri: uri,
              domain: hosterName,
              isDirect: false,
              canExtractLink: true);
          setState(() {});
          continue;
        }
        DownloadSourcesRepository().isDirectDownload(uri).then((isDirect) {
          final domain =
              isDirect ? "Direct download" : StringHelper.getDomainName(uri);
          urlHosters[uri] = HosterInfo(
              uri: uri,
              domain: domain,
              isDirect: isDirect,
              canExtractLink: isDirect);
          setState(() {});
        });
      }
    }
  }

  loadResults() {
    var provider = Provider.of<DownloadSourcesProvider>(context, listen: false);
    List<DownloadSourceWithDownloads> sourcesWithDownloads =
        provider.findRomSourcesWithDownloads(widget.rom);

    final List<_Result> filteredResults = [];

    for (final source in sourcesWithDownloads) {
      for (final sourceDownload in source.downloads!) {
        filteredResults.add(_Result(
          rom: sourceDownload,
          sourceTitle: source.sourceInfo!.title,
        ));
      }
    }
    results = filteredResults;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadResults();
    fetchSingleSourcesHosters();
    SettingsService().get(SettingsKeys.ENABLE_EXTRACTION).then((value) {
      setState(() {
        extractAfterDownload = value ?? false;
      });
    });
  }

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

  Future handleDownloadSourceSelected(DownloadSourceRom sourceRom) async {
    const loadingTitle = "Preparing download...";
    const loadingMessage =
        "Retrieving download link information please wait...";
    if (sourceRom.uris == null || sourceRom.uris!.isEmpty) {
      AlertsService.showErrorSnackbar(
          "No download links available for ${sourceRom.title}");
      return;
    }
    // When there's more than 1 uri, show the hoster selection dialog
    if (sourceRom.uris!.length > 1) {
      var selectedHoster = await showDialog<HosterInfo>(
        context: context,
        builder: (_) => DownloadSourceHosterSelectDialog(
          uris: sourceRom.uris!,
        ),
      );
      if (selectedHoster != null) {
        if (selectedHoster.isDirect) {
          Navigator.pop(
              context,
              RomDownloadSourcesDialogResult(
                  rom: sourceRom.copyWith(
                    uris: [selectedHoster.uri],
                    extractableUrl: selectedHoster.uri,
                  ),
                  extractAfterDownload: extractAfterDownload));
          return;
        }
        var loading = AlertsService.showLoadingAlert(
            navigatorContext!, loadingTitle, loadingMessage);
        final selectedHosterUrl = selectedHoster.uri;
        String? directDownloadLink = null;
        try {
          directDownloadLink = await DownloadSourcesRepository()
              .extractDirectDownloadUrl(selectedHoster.uri);
          loading.close();
        } catch (e) {
          loading.close();
          if (e is DownloadRequireManualException) {
            directDownloadLink = await Navigator.of(context).push<String?>(
              MaterialPageRoute(
                builder: (_) =>
                    DownloadLinkWebExtractor(rawLink: selectedHoster.uri),
                fullscreenDialog: true, // opcional
              ),
            );
          } else {
            AlertsService.showErrorSnackbar(e.toString());
            return;
          }
        }

        if (directDownloadLink == null || directDownloadLink.isEmpty) {
          AlertsService.showErrorSnackbar(
              "Could not extract download link for ${sourceRom.title}");
          return;
        }
        var romDownload = sourceRom.copyWith(
          fileName: selectedHoster.fileName,
          uris: [directDownloadLink],
          extractableUrl: selectedHosterUrl,
        );
        Navigator.pop(
            context,
            RomDownloadSourcesDialogResult(
                rom: romDownload, extractAfterDownload: extractAfterDownload));
        return;
      }

      return;
    }

    // When there's just one uri, try to extract the direct download link
    var loading =
        AlertsService.showLoadingAlert(context, loadingTitle, loadingMessage);
    if (await DownloadSourcesRepository()
        .isDirectDownload(sourceRom.uris!.first)) {
      loading.close();
      var romDownload = sourceRom.copyWith(
        uris: [sourceRom.uris!.first],
        extractableUrl: sourceRom.uris!.first,
      );
      Navigator.pop(
          context,
          RomDownloadSourcesDialogResult(
            rom: romDownload,
            extractAfterDownload: extractAfterDownload,
          ));
      return;
    }
    var link = null;
    var fileName = null;
    final sourceRomLink = sourceRom.uris!.first;
    try {
      link = await DownloadSourcesRepository()
          .extractDirectDownloadUrl(sourceRomLink);
      fileName =
          await DownloadSourcesRepository().getHosterFileName(sourceRomLink);
    } catch (e) {
      loading.close();
      if (e is DownloadRequireManualException) {
        link = await Navigator.of(context).push<String?>(
          MaterialPageRoute(
            builder: (_) => DownloadLinkWebExtractor(rawLink: sourceRomLink),
            fullscreenDialog: true,
          ),
        );
      } else {
        Future.microtask(() {
          AlertsService.showErrorSnackbar(e.toString());
        });
        return;
      }
    } finally {
      loading.close();
    }

    if (link == null || link.isEmpty) {
      Future.microtask(() {
        AlertsService.showErrorSnackbar(
            "Could not extract download link for ${sourceRom.title}");
      });
      return;
    }
    Navigator.pop(
        context,
        RomDownloadSourcesDialogResult(
          rom: sourceRom.copyWith(
            fileName: fileName,
            uris: [link],
            extractableUrl: sourceRomLink,
          ),
          extractAfterDownload: extractAfterDownload,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Available download options"),
      content: SizedBox(
        width: 420,
        height: 420,
        child: results.isEmpty
            ? const Center(
                child: Text(
                  'No matching sources found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (_, index) {
                        final item = results[index];
                        var prefix = item.rom.uris!.length > 1
                            ? '${item.rom.uris!.length} hosters'
                            : urlHosters.containsKey(item.rom.uris!.first)
                                ? urlHosters[item.rom.uris!.first]!.domain
                                : 'Loading...';
                        return ListTile(
                          leading: const Icon(Icons.cloud),
                          title: Text(
                            item.rom.title!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Opacity(
                            opacity: 0.7,
                            child: Text(
                              ' ${item.sourceTitle} • $prefix  • ${item.rom.fileSize ?? "--"}',
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
                  CheckboxListTile(
                    value: extractAfterDownload,
                    onChanged: (checked) => {
                      setState(() {
                        extractAfterDownload = checked ?? false;
                      })
                    },
                    title: Text("Extract contents after download"),
                  )
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

class _Result {
  final DownloadSourceRom rom;
  final String? sourceTitle;

  _Result({
    required this.rom,
    required this.sourceTitle,
  });
}
