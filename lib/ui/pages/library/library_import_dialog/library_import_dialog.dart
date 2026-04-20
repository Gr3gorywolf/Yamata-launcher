import 'dart:io';

import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/ui/widgets/dialog_section_item.dart';
import 'package:yamata_launcher/ui/widgets/rom_scrape_dialog.dart';
import 'package:yamata_launcher/ui/widgets/searchable_dropdown_form_field.dart';
import 'package:yamata_launcher/utils/custom_validators.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class LibraryImportDialog extends StatefulWidget {
  final RomLibraryItem? libraryItem;
  final bool canEditConsole;
  final bool canEditPath;
  final Function(RomInfo info, String filePath) onPicked;

  LibraryImportDialog(
      {super.key,
      required this.onPicked,
      this.libraryItem,
      this.canEditConsole = true,
      this.canEditPath = true});

  static show(
      BuildContext context, Function(RomInfo info, String filePath) onPicked,
      {RomLibraryItem? libraryItem,
      bool canEditConsole = true,
      bool canEditPath = true}) {
    showDialog(
      context: context,
      builder: (context) => LibraryImportDialog(
        onPicked: onPicked,
        libraryItem: libraryItem,
        canEditConsole: canEditConsole,
        canEditPath: canEditPath,
      ),
    );
  }

  @override
  State<LibraryImportDialog> createState() => _LibraryImportDialogState();
}

class _LibraryImportDialogState extends State<LibraryImportDialog> {
  late final List<Console> consoles;
  String detailsUrl = "";
  bool isFetchingMetadata = false;

  late final FormGroup form = FormGroup({
    'title': FormControl<String>(
      value: '',
      validators: [Validators.required],
    ),
    'console': FormControl<String>(
      value: '',
      validators: [Validators.required],
      disabled: !widget.canEditConsole,
    ),
    'romPath': FormControl<String>(
      value: '',
      validators: [Validators.required],
    ),
    'portraitUrl': FormControl<String>(
      value: '',
      validators: [CustomValidators.urlValidator],
    ),
    'gameplayUrl': FormControl<String>(
      value: '',
      validators: [CustomValidators.urlValidator],
    ),
  });

  bool get isEditing => widget.libraryItem != null;

  @override
  void initState() {
    super.initState();
    consoles = ConsoleService.getConsoles(includeUnsupported: true);
    if (isEditing) {
      final item = widget.libraryItem!;
      form.control('title').value = item.rom.name;
      form.control('console').value = item.rom.console;
      form.control('romPath').value = item.filePath;
      form.control('portraitUrl').value = item.rom.portrait ?? '';
      form.control('gameplayUrl').value =
          item.rom.gameplayCovers?.isNotEmpty == true
              ? item.rom.gameplayCovers!.first
              : '';
      detailsUrl = item.rom.detailsUrl ?? '';
    }
  }

  @override
  void dispose() {
    form.dispose();
    super.dispose();
  }

  Future<void> _pickRomPath() async {
    final file = await FileSystemService.showFilePicker();
    if (file == null) return;

    form.control('romPath').value = file;

    // Auto-set title if empty
    final titleControl = form.control('title') as FormControl<String>;
    if ((titleControl.value ?? '').trim().isEmpty) {
      titleControl.value = StringHelper.getTitleFromFile(file);
    }
  }

  void _onScrape(RomInfo info) {
    form.control('title').value = info.name;
    if (widget.canEditConsole) {
      form.control('console').value = info.console;
    }
    form.control('portraitUrl').value = info.portrait ?? '';
    form.control('gameplayUrl').value = info.gameplayCovers?.isNotEmpty == true
        ? info.gameplayCovers!.first
        : '';

    detailsUrl = info.detailsUrl ?? '';
  }

  void _onImport() {
    form.markAllAsTouched();
    if (!form.valid) return;

    final title = (form.control('title').value as String).trim();
    final console = (form.control('console').value as String).trim();
    final romPath = (form.control('romPath').value as String).trim();

    final portrait = (form.control('portraitUrl').value as String).trim();
    final gameplay = (form.control('gameplayUrl').value as String).trim();

    final romSlug = RomService.getRomSlug(console.toLowerCase(), title);

    final romInfo = RomInfo(
      slug: romSlug,
      name: title,
      portrait: portrait.isEmpty ? null : portrait,
      gameplayCovers: gameplay.isEmpty ? null : [gameplay],
      console: console.toLowerCase(),
      detailsUrl: detailsUrl.trim(),
    );

    widget.onPicked(romInfo, romPath);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveForm(
      formGroup: form,
      child: AlertDialog(
        title: Text(isEditing ? 'Edit Game Metadata' : 'Import Game'),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        contentPadding: const EdgeInsets.all(10.0),
        content: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450, minWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DialogSectionItem(
                  title: "Game Title",
                  icon: Icons.title,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        final title =
                            (form.control('title').value as String?) ?? '';
                        RomScrapeDialog.show(context, title, _onScrape);
                      },
                    ),
                  ],
                  content: ReactiveTextField<String>(
                    formControlName: 'title',
                    decoration: _inputDecoration(hintText: "Game title"),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      final title =
                          (form.control('title').value as String?) ?? '';
                      RomScrapeDialog.show(context, title, _onScrape);
                    },
                  ),
                ),
                if (widget.canEditConsole)
                  DialogSectionItem(
                    title: "Console",
                    icon: Icons.videogame_asset,
                    actions: const [],
                    content: ReactiveSearchableDropdownField<String>(
                      formControlName: 'console',
                      decoration: _inputDecoration(hintText: "Select console"),
                      items: consoles
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c.slug,
                              child: Text(c.name ?? ""),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                if (widget.canEditPath)
                  DialogSectionItem(
                    title: "Game Executable/File",
                    icon: Icons.description,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: _pickRomPath,
                      ),
                    ],
                    content: ReactiveValueListenableBuilder<String>(
                      formControlName: 'romPath',
                      builder: (context, control, child) {
                        final romPath = (control.value ?? '').trim();
                        return Text(
                          romPath.isEmpty ? "No file selected" : romPath,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                DialogSectionItem(
                  title: "Portrait (Optional)",
                  icon: Icons.image,
                  actions: const [],
                  content: _buildImageFormField('portraitUrl'),
                ),
                DialogSectionItem(
                  title: "Gameplay Cover (Optional)",
                  icon: Icons.collections,
                  actions: const [],
                  content: _buildImageFormField('gameplayUrl'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ReactiveFormConsumer(
            builder: (context, form, _) {
              return TextButton(
                onPressed: form.valid ? _onImport : null,
                child: Text(isEditing ? 'Save' : 'Import'),
              );
            },
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({required String hintText}) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  );
}

Widget _buildImageFormField(String name) {
  return ReactiveValueListenableBuilder<String>(
    formControlName: name,
    builder: (context, control, _) {
      final url = (control.value ?? '').trim();
      final isValidUrl = Uri.tryParse(url)?.isAbsolute == true;
      return Row(
        children: [
          if (isValidUrl)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 46,
                width: 46,
                cacheHeight: 180,
                cacheWidth: 180,
                key: ValueKey(url),
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                fit: BoxFit.cover,
              ),
            ),
          if (isValidUrl) const SizedBox(width: 10),
          Expanded(
            child: ReactiveTextField<String>(
              formControlName: name,
              decoration: _inputDecoration(
                hintText: "Optional image URL",
              ),
            ),
          ),
        ],
      );
    },
  );
}
