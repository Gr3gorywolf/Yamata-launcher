import 'package:flutter/material.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/ui/widgets/hint_banner.dart';
import 'package:yamata_launcher/ui/widgets/searchable_dropdown_form_field.dart';

class LibraryMassImportSetupStep extends StatelessWidget {
  final List<Console> availableConsoles;
  final String scanFolder;
  final String selectedConsole;
  final String selectedConsoleName;
  final VoidCallback onSelectFolder;
  final ValueChanged<String?> onSelectConsole;
  final VoidCallback onStartInitialScrape;

  const LibraryMassImportSetupStep({
    super.key,
    required this.availableConsoles,
    required this.scanFolder,
    required this.selectedConsole,
    required this.selectedConsoleName,
    required this.onSelectFolder,
    required this.onSelectConsole,
    required this.onStartInitialScrape,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 90,
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
                      'Importer setup',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Point the importer to a folder, optionally narrow it down to a single console, and then kick off the initial scrape preview.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 28),
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
                          onPressed: onSelectFolder,
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
                      items: availableConsoles
                          .map(
                            (console) => DropdownMenuItem<String>(
                              value: console.slug ?? '',
                              child: Text(console.name ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: onSelectConsole,
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
                        onPressed:
                            scanFolder.isEmpty ? null : onStartInitialScrape,
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

class _LibraryMassImportSummaryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _LibraryMassImportSummaryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
