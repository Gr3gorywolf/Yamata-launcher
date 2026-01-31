import 'package:flutter/material.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:yamata_launcher/ui/widgets/searchable_dropdown_form_field.dart';

enum DownloadSourceType { Yamata, Hydra }

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

  _handleSetSource(DownloadSourceWithDownloads? sourceToUpdate) async {
    var type = DownloadSourceType.Yamata;
    var result = sourceToUpdate == null
        ? await AlertsService.showPrompt(
            context,
            "Add Download Source",
            message: "Enter the URL of the download source:",
            inputPlaceholder: "Source URL",
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
    var loadingHandle = AlertsService.showLoadingAlert(context,
        "Fetching Source", "Please wait while the source is being fetched...");
    final source =
        await DownloadSourcesRepository().fetchDownloadSource(result, type);
    loadingHandle.close();
    if (source != null) {
      source.sourceInfo.downloadUrl = result;
      final provider =
          Provider.of<DownloadSourcesProvider>(context, listen: false);
      var success = await provider.setDownloadSource(source);
      if (success) {
        AlertsService.showSnackbar(
            sourceToUpdate == null
                ? "Source added successfully"
                : "Source updated successfully",
            ctx: context);
      } else {
        AlertsService.showErrorSnackbar("This source already exists",
            ctx: context);
      }
    } else {
      AlertsService.showErrorSnackbar("Could not fetch source", ctx: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    var provider = DownloadSourcesProvider.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Sources'),
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
            itemBuilder: (_, index) {
              final source = provider.downloadSources[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(source.sourceInfo!.title!),
                  subtitle: Opacity(
                      opacity: 0.7,
                      child:
                          Text('${source.downloads!.length} roms available')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
