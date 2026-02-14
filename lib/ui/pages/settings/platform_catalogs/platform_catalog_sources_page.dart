import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/platform_catalog_source.dart';
import 'package:yamata_launcher/repository/platform_catalog_sources_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';
import 'package:path/path.dart' as p;

class ConsoleSourcesPage extends StatefulWidget {
  @override
  _ConsoleSourcesPageState createState() => _ConsoleSourcesPageState();
}

class _ConsoleSourcesPageState extends State<ConsoleSourcesPage> {
  handleSetConsoleSource() async {
    var result = await AlertsService.showPrompt(
        context, 'Add Game Catalog Source',
        inputPlaceholder: 'Enter game catalog source URL',
        message:
            "The game catalog source must be a valid URL pointing to a JSON file containing game catalog definitions.");
    if (result != null && result.isNotEmpty) {
      var loading = AlertsService.showLoadingAlert(
          context,
          "Downloading game catalog source...",
          "Please wait while the game catalog source is being downloaded...");
      final source = await ConsoleSourcesRepository().fetchSource(result);
      loading.close();
      if (source != null) {
        source.downloadUrl = result;
        var validationError =
            ConsoleService.validatePlatformCatalogSource(source);
        if (validationError != null) {
          AlertsService.showErrorSnackbar(validationError, ctx: context);
          return;
        }
        bool added = await ConsoleService.addConsoleSource(source);
        if (added) {
          setState(() {});
          AlertsService.showSnackbar("Game catalog source added successfully.",
              ctx: context);
        } else {
          AlertsService.showErrorSnackbar("Game catalog source already exists.",
              ctx: context);
        }
      } else {
        AlertsService.showErrorSnackbar("Failed to fetch game catalog source.",
            ctx: context);
      }
    }
  }

  handleUpdateConsoleSource(PlatformCatalogSource sourceToUpdate) async {
    var source = await ConsoleService.getConsoleSource(sourceToUpdate);
    if (source == null) {
      AlertsService.showErrorSnackbar("Failed to fetch game catalog source.",
          ctx: context);
      return;
    }
    var loading = AlertsService.showLoadingAlert(
        context,
        "Updating game catalog source...",
        "Please wait while the game catalog source is being updated...");
    final updatedSource =
        await ConsoleSourcesRepository().fetchSource(source.downloadUrl ?? "");
    loading.close();
    if (updatedSource != null) {
      updatedSource.downloadUrl = source.downloadUrl;
      var validationError =
          ConsoleService.validatePlatformCatalogSource(source);
      if (validationError != null) {
        AlertsService.showErrorSnackbar(validationError, ctx: context);
        return;
      }
      bool added = await ConsoleService.updateConsoleSource(updatedSource);
      if (added) {
        setState(() {});
        AlertsService.showSnackbar("Game catalog source updated successfully.",
            ctx: context);
      } else {
        AlertsService.showErrorSnackbar("Game catalog source doesn't exist.",
            ctx: context);
      }
    } else {
      AlertsService.showErrorSnackbar("Failed to fetch game catalog source.",
          ctx: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Catalog Sources'),
      ),
      body: Builder(
        builder: (builder) {
          if (ConsoleService.externalplatformCatalogs.isEmpty) {
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
            itemCount: ConsoleService.externalplatformCatalogs.length,
            itemBuilder: (_, index) {
              final source = ConsoleService.externalplatformCatalogs[index];
              return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text((source.sourceName ?? "")),
                    subtitle: Opacity(
                        opacity: 0.7, child: Text(source.console.name ?? "")),
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
      floatingActionButton: !ConsoleService.externalplatformCatalogs.isEmpty
          ? FloatingActionButton.extended(
              onPressed: handleSetConsoleSource,
              icon: const Icon(Icons.add),
              label: const Text('Add Catalog Source'),
            )
          : null,
    );
  }
}
