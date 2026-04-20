import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
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
            floatingActionButton:
                controller.stage == LibraryMassImportStage.review
                    ? FloatingActionButton.extended(
                        onPressed: controller.canCompleteImport
                            ? () {
                                _showPendingMessage(
                                  'Complete import is visual-only for now.',
                                );
                              }
                            : null,
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
