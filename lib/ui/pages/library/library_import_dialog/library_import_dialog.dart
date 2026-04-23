import 'dart:io';

import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/models/artwork_scraper.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/repository/game_metadata_repository.dart';
import 'package:yamata_launcher/repository/game_metadata_repository.dart';
import 'package:yamata_launcher/services/alerts_service.dart';
import 'package:yamata_launcher/services/assets_service.dart';
import 'package:yamata_launcher/services/cache_service.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/services/scrapers/metadata/steamgrid_scraper.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/ui/widgets/art_picker.dart';
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
      validators: [if (widget.canEditPath) Validators.required],
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
    var portraitChanged = form.control('portraitUrl').value != info.portrait;
    if (portraitChanged) {
      updatePortraitCache(info, shouldRegenerate: true);
    }
    form.control('title').value = info.name;
    if (widget.canEditConsole || !widget.libraryItem!.rom.isValid) {
      form.control('console').value = info.console;
    }
    form.control('portraitUrl').value = info.portrait ?? '';
    form.control('gameplayUrl').value = info.gameplayCovers?.isNotEmpty == true
        ? info.gameplayCovers!.first
        : '';

    detailsUrl = info.detailsUrl ?? '';
  }

  (RomInfo, String)? _buildRomInfo() {
    if (!form.valid) return null;

    final title = (form.control('title').value as String).trim();
    final console = (form.control('console').value as String).trim();
    String romPath = '';
    if (widget.canEditPath) {
      romPath = (form.control('romPath').value as String).trim();
    }
    final portrait = (form.control('portraitUrl').value as String).trim();
    final gameplay = (form.control('gameplayUrl').value as String).trim();
    final romSlug = RomService.getRomSlug(console.toLowerCase(), title);
    return (
      RomInfo(
        slug: romSlug,
        name: title,
        portrait: portrait.isEmpty ? null : portrait,
        gameplayCovers: gameplay.isEmpty ? null : [gameplay],
        console: console.toLowerCase(),
        detailsUrl: detailsUrl.trim(),
      ),
      romPath
    );
  }

  void _onImport() {
    form.markAllAsTouched();
    var result = _buildRomInfo();
    if (result == null) {
      return;
    }
    var (romInfo, romPath) = result;
    updatePortraitCache(romInfo, shouldRegenerate: true);
    widget.onPicked(romInfo, romPath);
    Navigator.of(context).pop();
  }

  void updatePortraitCache(RomInfo romInfo,
      {bool shouldRegenerate = false}) async {
    if (shouldRegenerate) {
      await RomService.deleteRomPortraitCache(romInfo);
    }
    if (await SettingsService().get<bool>(SettingsKeys.ENABLE_IMAGE_CACHING)) {
      await RomService.catchRomPortrait(romInfo,
          shouldRegenerate: shouldRegenerate);
    }
  }

  void handlePickArtType(ArtType type) async {
    var artworkTypeMap = {
      ArtType.portrait: SteamGridArtType.grids,
      ArtType.gameplay: SteamGridArtType.heroes,
    };
    var loading = AlertsService.showLoadingAlert(
        navigatorContext!, "Looking for artworks", "Please wait...");
    var pickedProvider = await AlertsService.showPicker(
        context,
        "Select Artwork Provider",
        ArtworkProviders.values
            .map((p) => PickerOption(label: p.value, value: p))
            .toList());

    if (pickedProvider == null) {
      loading.close();
      return;
    }
    List<String> arts = [];
    try {
      var res = await GameMetadataRepository.fetchArtworkFromProvider(
          pickedProvider.value, type, form.control('title').value ?? '');
      if (res != null) {
        arts = res;
      }
    } catch (e) {
      print("Error picking artwork provider: $e");
      loading.close();
      Future.microtask(() => AlertsService.showErrorSnackbar(
          "Failed to fetch artworks from the selected provider. Please try again. $e"));
      return;
    }
    loading.close();
    if (arts.isEmpty) {
      Future.microtask(() => AlertsService.showSnackbar(
          "No artworks found for the current game title."));
      return;
    }

    var result = await ArtPicker.show(context, arts: arts);
    if (result != null) {
      form
          .control(type == ArtType.portrait ? 'portraitUrl' : 'gameplayUrl')
          .value = result;

      if (artworkTypeMap[type] == SteamGridArtType.grids) {
        var result = _buildRomInfo();
        if (result == null) {
          return;
        }
        var (romInfo, romPath) = result;
        RomService.catchRomPortrait(romInfo, shouldRegenerate: true);
      }
    }
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
                  helperText:
                      "Use the 'Search' icon or submit the title to look for metadata and artworks on the game database.",
                  actions: [
                    IconButton(
                      icon: Icon(Icons.travel_explore),
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
                  actions: [
                    IconButton(
                        onPressed: () {
                          handlePickArtType(ArtType.portrait);
                        },
                        icon: Icon(Icons.travel_explore))
                  ],
                  content: _buildImageFormField('portraitUrl'),
                ),
                DialogSectionItem(
                  title: "Gameplay Cover (Optional)",
                  icon: Icons.collections,
                  actions: [
                    IconButton(
                        onPressed: () {
                          handlePickArtType(ArtType.gameplay);
                        },
                        icon: Icon(Icons.travel_explore))
                  ],
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
