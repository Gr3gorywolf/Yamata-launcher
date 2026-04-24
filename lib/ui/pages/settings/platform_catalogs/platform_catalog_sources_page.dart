import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yamata_launcher/models/platform_catalog_source.dart';
import 'package:yamata_launcher/repository/platform_catalog_sources_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/ui/widgets/gamepad_aware_floating_action_button.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';

class ConsoleSourcesPage extends StatefulWidget {
  @override
  _ConsoleSourcesPageState createState() => _ConsoleSourcesPageState();
}

class _ConsoleSourcesPageState extends State<ConsoleSourcesPage> {
  Future<void> _handleUpdateAllConsoleSources() async {
    final sources = ConsoleService.externalPlatformCatalogs;

    if (sources.isEmpty) return;

    int completed = 0;
    final total = sources.length;
    ValueNotifier<double> progressNotifier = ValueNotifier<double>(0);
    final loading = AlertsService.showLoadingAlert(
      context,
      "Updating Catalog Sources",
      "Updating all catalog sources...",
      progressNotifier: progressNotifier,
    );

    try {
      final futures = sources.map((source) async {
        try {
          final existing = await ConsoleService.getConsoleSource(source);

          if (existing != null) {
            await _fetchValidateAndSaveConsoleSource(
              url: existing.downloadUrl ?? "",
              isUpdate: true,
            );
          }
        } catch (e) {
          debugPrint("Error updating catalog source: $e");
        } finally {
          completed++;
          final percent = (completed / total * 100).toInt() / 100;
          progressNotifier.value = percent.toDouble();
        }
      }).toList();

      await Future.wait(futures);

      setState(() {});

      AlertsService.showSnackbar(
        "All catalog sources updated successfully",
        ctx: context,
      );
    } catch (e) {
      AlertsService.showErrorSnackbar(
        "Error updating catalog sources",
        ctx: context,
      );
    } finally {
      loading.close();
    }
  }

  Future<bool> _fetchValidateAndSaveConsoleSource({
    required String url,
    bool isUpdate = false,
  }) async {
    final source = await ConsoleSourcesRepository().fetchSource(url);

    if (source == null) return false;

    source.downloadUrl = url;

    final validationError =
        ConsoleService.validatePlatformCatalogSource(source);

    if (validationError != null) {
      AlertsService.showErrorSnackbar(validationError, ctx: context);
      return false;
    }

    if (isUpdate) {
      return await ConsoleService.updateConsoleSource(source);
    } else {
      return await ConsoleService.addConsoleSource(source);
    }
  }

  handleSetConsoleSource() async {
    var result = await AlertsService.showPrompt(
      context,
      'Add Game Catalog Source',
      inputPlaceholder: 'Enter game catalog source URL',
      canPasteText: true,
      message:
          "The game catalog source must be a valid URL pointing to a JSON file containing game catalog definitions.",
    );

    if (result == null || result.isEmpty) return;

    var loading = AlertsService.showLoadingAlert(
      context,
      "Downloading game catalog source...",
      "Please wait while the game catalog source is being downloaded...",
    );

    final success = await _fetchValidateAndSaveConsoleSource(
      url: result,
      isUpdate: false,
    );

    loading.close();

    if (success) {
      setState(() {});
      AlertsService.showSnackbar(
        "Game catalog source added successfully.",
        ctx: context,
      );
    } else {
      AlertsService.showErrorSnackbar(
        "Game catalog source already exists or failed.",
        ctx: context,
      );
    }
  }

  handleUpdateConsoleSource(PlatformCatalogSource sourceToUpdate) async {
    var source = await ConsoleService.getConsoleSource(sourceToUpdate);

    if (source == null) {
      AlertsService.showErrorSnackbar(
        "Failed to fetch game catalog source.",
        ctx: context,
      );
      return;
    }

    var loading = AlertsService.showLoadingAlert(
      context,
      "Updating game catalog source...",
      "Please wait while the game catalog source is being updated...",
    );

    final success = await _fetchValidateAndSaveConsoleSource(
      url: source.downloadUrl ?? "",
      isUpdate: true,
    );

    loading.close();

    if (success) {
      setState(() {});
      AlertsService.showSnackbar(
        "Game catalog source updated successfully.",
        ctx: context,
      );
    } else {
      AlertsService.showErrorSnackbar(
        "Game catalog source doesn't exist or failed.",
        ctx: context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Catalog Sources'),
        actions: [
          if (ConsoleService.externalPlatformCatalogs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _handleUpdateAllConsoleSources,
              tooltip: "Update All Catalog Sources",
            )
        ],
      ),
      body: Builder(
        builder: (builder) {
          if (ConsoleService.externalPlatformCatalogs.isEmpty) {
            return EmptyPlaceholder(
              icon: Icons.gamepad,
              title: 'No catalog sources',
              description:
                  "You have not added any catalog sources yet. Add a source to view more game catalogs on the explore section.",
              action: PlaceHolderAction(
                label: 'Add Source',
                onPressed: () => handleSetConsoleSource(),
              ),
            );
          }

          return ListView.builder(
            itemCount: ConsoleService.externalPlatformCatalogs.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (_, index) {
              final source = ConsoleService.externalPlatformCatalogs[index];
              return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: Icon(Icons.gamepad),
                    title: Text((source.sourceName ?? "")),
                    subtitle: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Opacity(
                            opacity: 0.7,
                            child: Text(source.console.name ?? "")),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: source.downloadUrl!));
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
                                      "This is the url for ${source.sourceName} ${source.console.name} catalog source on Yamata Launcher:\n\n${source.downloadUrl!}");
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
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            ConsoleService.deleteConsoleSource(source);
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            handleUpdateConsoleSource(source);
                          },
                        ),
                      ],
                    ),
                  ));
            },
          );
        },
      ),
      floatingActionButton: !ConsoleService.externalPlatformCatalogs.isEmpty
          ? GamepadAwareFloatingActionButton(
              onPressed: handleSetConsoleSource,
              icon: Icons.add,
              title: 'Add Catalog Source',
            )
          : null,
    );
  }
}
