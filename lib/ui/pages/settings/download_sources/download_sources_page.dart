import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/ui/widgets/searchable_dropdown_form_field.dart';
import 'package:yamata_launcher/ui/widgets/status_tag.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';
import 'package:yamata_launcher/utils/time_helpers.dart';

class DownloadSourcesPage extends StatefulWidget {
  @override
  _DownloadSourcesPageState createState() => _DownloadSourcesPageState();
}

class _DownloadSourcesPageState extends State<DownloadSourcesPage> {
  _handleDeleteSource(DownloadSourceWithDownloads source) async {
    final confirmed = await AlertsService.showAlert(
      context,
      "Delete Download Source",
      "Are you sure you want to delete the source '${source.sourceInfo!.title}'?",
      callback: () {
        final provider =
            Provider.of<DownloadSourcesProvider>(context, listen: false);
        provider.removeDownloadSource(source);
        AlertsService.showSnackbar("Source deleted successfully");
      },
    );
  }

  Future<bool> _fetchAndSetSource({
    required String url,
    required DownloadSourceType type,
  }) async {
    final provider =
        Provider.of<DownloadSourcesProvider>(context, listen: false);

    final source =
        await DownloadSourcesRepository().fetchDownloadSource(url, type);

    if (source == null) return false;

    source.sourceInfo.downloadUrl = url;
    source.sourceInfo.type = type;

    return await provider.setDownloadSource(source);
  }

  Future<void> _handleUpdateAllSources() async {
    final provider =
        Provider.of<DownloadSourcesProvider>(context, listen: false);

    final sources = provider.downloadSources;
    if (sources.isEmpty) return;

    int completed = 0;
    final total = sources.length;
    ValueNotifier<double> progressNotifier = ValueNotifier<double>(0);
    final loadingHandle = AlertsService.showLoadingAlert(
      navigatorContext!,
      "Updating Sources",
      "Updating all sources...",
      progressNotifier: progressNotifier,
    );

    try {
      final futures = sources.map((source) async {
        try {
          final url = source.sourceInfo!.downloadUrl!;
          final type = source.sourceInfo!.type!;

          await _fetchAndSetSource(
            url: url,
            type: type,
          );
        } catch (e) {
          debugPrint("Error updating source: $e");
        } finally {
          completed++;
          final percent = (completed / total * 100).toInt() / 100;
          progressNotifier.value = percent.toDouble();
        }
      }).toList();

      await Future.wait(futures);

      provider.checkForUpdates();

      AlertsService.showSnackbar(
        "All sources updated successfully",
        ctx: context,
      );
    } catch (e) {
      AlertsService.showErrorSnackbar(
        "Error updating sources",
        ctx: context,
      );
    } finally {
      loadingHandle.close();
    }
  }

  _handleSetSource(DownloadSourceWithDownloads? sourceToUpdate) async {
    var type = sourceToUpdate?.sourceInfo?.type ?? DownloadSourceType.Yamata;
    var result = sourceToUpdate == null
        ? await AlertsService.showPrompt(
            context,
            "Add Download Source",
            message: "Enter the URL of the download source:",
            inputPlaceholder: "Source URL",
            canPasteText: true,
            extraContent: DialogSectionItem(
              title: "Download Source Type",
              icon: Icons.cloud,
              actions: [],
              content: SearchableDropdownFormField<DownloadSourceType>(
                value: type,
                items: [
                  DropdownMenuItem(
                    value: DownloadSourceType.Yamata,
                    child: Text("Yamata Source"),
                  ),
                  DropdownMenuItem(
                    value: DownloadSourceType.Hydra,
                    child: Text("Hydra Source"),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    type = value;
                  }
                },
              ),
            ),
          )
        : sourceToUpdate.sourceInfo!.downloadUrl;
    if (result == null || result.isEmpty) {
      return;
    }
    var loadingHandle = AlertsService.showLoadingAlert(navigatorContext!,
        "Fetching Source", "Please wait while the source is being fetched...");
    final success = await _fetchAndSetSource(
      url: result,
      type: type,
    );

    loadingHandle.close();

    if (success) {
      final provider =
          Provider.of<DownloadSourcesProvider>(context, listen: false);
      provider.checkForUpdates();
      AlertsService.showSnackbar(
        sourceToUpdate == null
            ? "Source added successfully"
            : "Source updated successfully",
        ctx: context,
      );
    } else {
      AlertsService.showErrorSnackbar("Failed to add this source",
          ctx: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    var provider = DownloadSourcesProvider.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Sources'),
        actions: [
          if (provider.downloadSources.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _handleUpdateAllSources,
              tooltip: "Update All Sources",
            )
        ],
      ),
      body: Builder(
        builder: (
          _,
        ) {
          if (provider.downloadSources.isEmpty) {
            return EmptyPlaceholder(
              icon: Icons.cloud_download,
              title: 'No download sources',
              description:
                  "You have not added any download sources yet. Add a source to start downloading ROMs.",
              action: PlaceHolderAction(
                label: 'Add Source',
                onPressed: () => _handleSetSource(null),
              ),
            );
          }
          return ListView.builder(
            itemCount: provider.downloadSources.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (_, index) {
              final source = provider.downloadSources[index];
              var hasUpdate = provider.sourceUrlsWithUpdates
                  .contains(source.sourceInfo!.downloadUrl);
              var timeAgo = source.sourceInfo?.lastUpdated != null
                  ? TimeHelpers.getTimeAgo(
                      DateTime.parse(source.sourceInfo!.lastUpdated!))
                  : "Unknown";

              var tags = [
                if (hasUpdate)
                  StatusTag(
                    text: "Update Available",
                    size: StatusTagSize.sm,
                    type: StatusTagType.success,
                  ),
                if (source.sourceInfo?.donationUrl != null)
                  StatusTag(
                    text: "Supports Donations",
                    size: StatusTagSize.sm,
                    type: StatusTagType.success,
                  ),
                if (source.sourceInfo?.requiresAuth == true)
                  StatusTag(
                    text: "Has Authentication",
                    size: StatusTagSize.sm,
                    type: StatusTagType.warning,
                  ),
              ];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(Icons.cloud_download),
                  title: Text(source.sourceInfo!.title!),
                  subtitle: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Opacity(
                          opacity: 0.7,
                          child: Text(
                              '${source.sourceInfo.type?.name} - ${StringHelper.formatNumber(source.downloads!.length)} games - Last Updated: $timeAgo')),
                      if (tags.length > 0) ...[
                        SizedBox(height: 4),
                        Row(children: [
                          ...tags
                              .map((tag) => [tag, SizedBox(width: 4)])
                              .expand((i) => i)
                        ])
                      ],
                      SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(
                                  text: source.sourceInfo!.downloadUrl!));
                              AlertsService.showSnackbar(
                                  "Source URL copied to clipboard");
                            },
                            icon: Icon(Icons.copy, size: 16),
                            label: Text("Copy URL"),
                          ),
                          if (Platform.isAndroid) ...[
                            SizedBox(width: 3),
                            TextButton.icon(
                              onPressed: () async {
                                SystemHelpers.androidShareWithChooser(
                                    "This is the url for ${source.sourceInfo!.title} ${source.sourceInfo!.type?.name} download source on Yamata Launcher:\n\n${source.sourceInfo!.downloadUrl!}");
                              },
                              icon: Icon(Icons.share, size: 16),
                              label: Text("Share"),
                            ),
                          ]
                        ],
                      )
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (source.sourceInfo?.donationUrl != null)
                        IconButton(
                          icon: const Icon(Icons.volunteer_activism),
                          onPressed: () => {
                            launchUrl(
                                Uri.parse(source.sourceInfo!.donationUrl!))
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _handleDeleteSource(source),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => _handleSetSource(source),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: !provider.downloadSources.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _handleSetSource(null),
              icon: const Icon(Icons.add),
              label: const Text('Add Download Source'),
            )
          : null,
    );
  }
}
