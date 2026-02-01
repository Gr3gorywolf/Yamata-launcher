import 'package:flutter/material.dart';
import 'package:sembast/sembast.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/custom_path_dao.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/console_source.dart';
import 'package:yamata_launcher/models/custom_download_path.dart';
import 'package:yamata_launcher/repository/console_sources_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/ui/pages/settings/custom_paths/custom_paths_form.dart';
import 'package:yamata_launcher/ui/widgets/empty_placeholder.dart';

class CustomPathsPage extends StatefulWidget {
  @override
  _CustomPathsPageState createState() => _CustomPathsPageState();
}

class _CustomPathsPageState extends State<CustomPathsPage> {
  List<CustomDownloadPath> paths = [];
  void handleAddPath() async {
    var result = await showDialog<CustomDownloadPath>(
        context: context,
        builder: (ctx) {
          return CustomPathsForm(
            existingConsoles: paths.map((e) => e.console).toList(),
          );
        });

    if (result != null) {
      if (db == null) {
        return;
      }
      final dao = CustomPathDao(db!);
      await dao.insert(result);
      paths.add(result);
      setState(() {});
    }
  }

  void handleUpdatePath(CustomDownloadPath path) async {
    var result = await showDialog<CustomDownloadPath>(
        context: context,
        builder: (ctx) {
          return CustomPathsForm(
            existingConsoles: [],
            editingPath: path,
          );
        });

    if (result != null) {
      if (db == null) {
        return;
      }
      final dao = CustomPathDao(db!);
      await dao.update(result);
      paths = paths
          .map((path) => path.console == result.console ? result : path)
          .toList();
      setState(() {});
    }
  }

  void handleDeletePath(String consoleSlug) async {
    if (db == null) {
      return;
    }
    final dao = CustomPathDao(db!);
    await dao.delete(consoleSlug);
    paths = paths.where((path) => path.console != consoleSlug).toList();
    setState(() {});
  }

  void loadCustomPaths() async {
    if (db == null) {
      return;
    }
    final dao = CustomPathDao(db!);
    paths = await dao.getAll();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    loadCustomPaths();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Download Paths'),
      ),
      body: Builder(
        builder: (builder) {
          if (paths.isEmpty) {
            return EmptyPlaceholder(
              icon: Icons.folder_special,
              title: 'No custom paths',
              description:
                  "You have not added any custom paths yet. Default folder paths will be used.",
              action: PlaceHolderAction(
                label: 'Add Custom Path',
                onPressed: () => handleAddPath(),
              ),
            );
          }

          return ListView.builder(
            itemCount: paths.length,
            itemBuilder: (_, index) {
              final path = paths[index];
              return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(
                        ConsoleService.getConsoleFromName(path.console)?.name ??
                            ""),
                    subtitle: Opacity(
                        opacity: 0.7, child: Text(path.folderPath ?? "")),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            handleDeletePath(path.console);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            handleUpdatePath(path);
                          },
                        ),
                      ],
                    ),
                  ));
            },
          );
        },
      ),
      floatingActionButton: !ConsoleService.consolesFromExternalSources.isEmpty
          ? FloatingActionButton.extended(
              onPressed: handleAddPath,
              icon: const Icon(Icons.add),
              label: const Text('Add Custom Path'),
            )
          : null,
    );
  }
}
