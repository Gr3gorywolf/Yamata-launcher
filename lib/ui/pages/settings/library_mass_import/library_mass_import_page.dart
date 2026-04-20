import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_controller.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_registry_sync_step.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_review_step.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_setup_step.dart';

class LibraryMassImportPage extends StatefulWidget {
  const LibraryMassImportPage({super.key});

  @override
  State<LibraryMassImportPage> createState() => _LibraryMassImportPageState();
}

class _LibraryMassImportPageState extends State<LibraryMassImportPage> {
  late final LibraryMassImportController _controller;
  @override
  void initState() {
    super.initState();
    _controller = LibraryMassImportController(
      availableConsoles: ConsoleService.getConsoles(
        includeUnsupported: true,
      ),
    );
    _startRegistrySync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startRegistrySync() async {
    try {
      await _controller.syncRegistry();
    } catch (er) {
      print('Error fetching launchbox registry: $er');
      AlertsService.showAlert(navigatorContext!, 'Error',
          'Failed to fetch launchbox registry. ${er.toString()}',
          cancelable: false,
          acceptTitle: 'Retry',
          callback: _startRegistrySync, onClose: () {
        if (!mounted) return;
        Navigator.of(context).pop();
      });
    }
  }

  void _showPendingMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _completeImport(bool skipUncompleted) async {
    var loading = AlertsService.showLoadingAlert(
      navigatorContext!,
      'Completing import...',
      "This might take a while depending on the number of games being imported.",
    );
    var itemsToAdd = [
      ..._controller.validGames,
      if (!skipUncompleted) ..._controller.needsScrapeGames
    ];
    var libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
    for (var item in itemsToAdd) {
      if (_controller.skippedResults.contains(item.libraryItem.rom.slug)) {
        continue;
      }
      await libraryProvider.addLibraryItem(item.libraryItem);
    }
    loading.close();
    Future.microtask(() {
      AlertsService.showSnackbar(
        'Import completed with ${_controller.validGames.length} games imported${!skipUncompleted && _controller.needsScrapeGames.length > 0 ? " and ${_controller.needsScrapeGames.length} games pending scrape" : ""}.',
      );
      _controller.backToSetup();
    });
  }

  void _handleImportTap() async {
    if (!_controller.canCompleteImport) {
      AlertsService.showErrorSnackbar(
          'The import is not ready to be completed. Please make sure all items are ready for import and try again.');
      return;
    }
    var needsScrapeGamesWithoutSkip = _controller.needsScrapeGames
        .where((game) =>
            !_controller.skippedResults.contains(game.libraryItem.rom.slug))
        .toList();
    if (needsScrapeGamesWithoutSkip.length > 0) {
      AlertsService.showAlert(navigatorContext!, 'Scraping required',
          'There are ${needsScrapeGamesWithoutSkip.length} games that have missing fields and needs to be scraped, do you want to add them to the library anyway?, you can always scrape them later on the game settings page.',
          acceptTitle: 'Proceed with missing scrapes',
          cancelable: true,
          additionalAction: TextButton(
              onPressed: () {
                Navigator.of(navigatorContext!).pop();
                _completeImport(true);
              },
              child: const Text('Proceed and skip pending scrapes')),
          callback: () {
        _completeImport(false);
      });
      return;
    }

    _completeImport(false);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<LibraryMassImportController>(
        builder: (context, controller, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Library Mass Import'),
            ),
            floatingActionButton: controller.stage ==
                    LibraryMassImportStage.review
                ? FloatingActionButton.extended(
                    onPressed:
                        controller.canCompleteImport ? _handleImportTap : null,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Complete import'),
                  )
                : null,
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (controller.stage) {
                LibraryMassImportStage.syncingRegistry =>
                  const LibraryMassImportRegistrySyncStep(
                    key: ValueKey('registry-sync'),
                  ),
                LibraryMassImportStage.setup =>
                  const LibraryMassImportSetupStep(
                    key: ValueKey('importer-setup'),
                  ),
                LibraryMassImportStage.review =>
                  const LibraryMassImportReviewStep(
                    key: ValueKey('review-state'),
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}
