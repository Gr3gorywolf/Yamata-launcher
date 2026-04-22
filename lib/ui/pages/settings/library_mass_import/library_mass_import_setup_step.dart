import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/os_service.dart';
import 'package:yamata_launcher/ui/pages/settings/library_mass_import/library_mass_import_controller.dart';
import 'package:yamata_launcher/ui/widgets/hint_banner.dart';
import 'package:yamata_launcher/ui/widgets/searchable_dropdown_form_field.dart';

class LibraryMassImportSetupStep extends StatelessWidget {
  const LibraryMassImportSetupStep({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = LibraryMassImportController.of(context);
    final List<Console> availableConsoles = controller.availableConsoles;
    final scanFolder = controller.scanFolder;
    final selectedConsole = controller.selectedConsole;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: SizedBox(
        height: FileSystemService.isDesktop
            ? MediaQuery.of(context).size.height - 90
            : null,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Import setup',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 0,
                      ),
                      title: Text(
                        'Scan path',
                        style: theme.textTheme.titleMedium,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          scanFolder.isEmpty
                              ? 'No folder selected yet'
                              : scanFolder,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      trailing: IconButton(
                          onPressed: controller.selectFolder,
                          icon: Icon(Icons.file_open)),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'ROM console',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SearchableDropdownFormField<String>(
                      value:
                          selectedConsole.isNotEmpty ? selectedConsole : null,
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All consoles'),
                        ),
                        ...availableConsoles
                            .map(
                              (console) => DropdownMenuItem<String>(
                                value: console.slug ?? '',
                                child: Text(console.name ?? ''),
                              ),
                            )
                            .toList()
                      ],
                      onChanged: controller.selectConsole,
                      decoration: InputDecoration(
                        hintText: 'All consoles',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    HintBanner(
                        text:
                            'Selecting a console increases scrape accuracy and helps reduce false positives during the first pass.'),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: scanFolder.isEmpty
                            ? null
                            : controller.startInitialScrape,
                        icon: const Icon(Icons.travel_explore),
                        label: const Text('Start initial scrape'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
