import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/library_dao.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';
import 'package:yamata_launcher/services/download_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/ui/widgets/view_mode_toggle.dart';
import 'package:provider/provider.dart';

class LibraryProvider extends ChangeNotifier {
  static LibraryProvider of(BuildContext ctx) {
    return Provider.of<LibraryProvider>(ctx);
  }

  Map<String, RomLibraryItem> _libraryItems = {};
  Set<String> _runningGames = {};
  int _version = 0;
  List<RomLibraryItem> get libraryItems => _libraryItems.values.toList();
  int get version => _version;

  @override
  void notifyListeners() {
    _version++;
    super.notifyListeners();
  }

  Future checkGamesExistence() async {
    final stopwatch = Stopwatch()..start();
    print("Checking installed games existence...");
    var batchSize = Platform.isAndroid ? 200 : 400;
    Iterable<RomLibraryItem> items =
        _libraryItems.values.where((e) => e.filePath?.isNotEmpty ?? false);
    final list = items.toList();
    for (int i = 0; i < list.length; i += batchSize) {
      final batch = list.skip(i).take(batchSize);

      await Future.wait(batch.map((item) async {
        final path = item.filePath!;
        item.doesExists = await File(path).exists();
      }));
    }
    stopwatch.stop();
    print(
        "Finished checking installed games existence in ${stopwatch.elapsedMilliseconds} ms");
    notifyListeners();
  }

  init() async {
    if (db == null) {
      return;
    }
    var library = await LibraryDao(db!).getAll();
    for (var item in library) {
      _libraryItems[item.rom.slug] = item;
    }
    checkGamesExistence();
    Timer.periodic(const Duration(minutes: 20), (_) async {
      await checkGamesExistence();
    });
  }

  List<RomLibraryItem> getDownloads() {
    return _libraryItems.values
        .where((item) => item.downloadedAt != null)
        .sorted((a, b) => a.addedAt!.compareTo(b.addedAt!))
        .toList();
  }

  List<RomLibraryItem> getBySlugs(List<String> slugs) {
    List<RomLibraryItem> items = [];
    for (var slug in slugs) {
      var item = _libraryItems[slug];
      if (item != null) {
        items.add(item);
      }
    }
    return items;
  }

  bool isRomReadyToPlay(String romSlug) {
    var item = _libraryItems[romSlug];
    if (item == null) {
      return false;
    }
    return item.filePath != null && item.filePath!.isNotEmpty;
  }

  bool isGameRunning(String slug) {
    return _runningGames.contains(slug);
  }

  setGameRunning(String slug, bool running) {
    if (running) {
      _runningGames.add(slug);
    } else {
      _runningGames.remove(slug);
    }
    notifyListeners();
  }

  RomLibraryItem? getLibraryItem(String romSlug) {
    return _libraryItems[romSlug];
  }

  RomLibraryItem addRomToLibrary(RomInfo rom) {
    var libraryItem = RomLibraryItem(rom: rom, addedAt: DateTime.now());
    var foundLibraryItem = _libraryItems[rom.slug];
    if (foundLibraryItem != null) {
      return foundLibraryItem;
    }
    addLibraryItem(libraryItem);
    return libraryItem;
  }

  addLibraryItem(RomLibraryItem item) async {
    if (db == null) {
      return;
    }
    await LibraryDao(db!).insert(item);
    item.doesExists = await File(item.filePath ?? '').exists();
    _libraryItems[item.rom.slug] = item;
    notifyListeners();
    if (await SettingsService().get<bool>(SettingsKeys.ENABLE_IMAGE_CACHING)) {
      DownloadService.catchRomPortrait(item.rom);
    }
  }

  removeLibraryItem(String romSlug) async {
    if (db == null) {
      return;
    }
    await LibraryDao(db!).delete(romSlug);
    _libraryItems.remove(romSlug);
    notifyListeners();
  }

  Future<void> updateLibraryItem(RomLibraryItem item,
      {String? originalSlug}) async {
    if (db == null) {
      return;
    }
    if (originalSlug != null && originalSlug != item.rom.slug) {
      // If the slug has changed, we need to remove the old entry and add a new one
      await LibraryDao(db!).delete(originalSlug);
      _libraryItems.remove(originalSlug);
      notifyListeners();
      Future.microtask(() {
        addLibraryItem(item);
      });
      return;
    }
    await LibraryDao(db!).update(item);
    _libraryItems[item.rom.slug] = item;
    item.doesExists = await File(item.filePath ?? '').exists();
    Future.microtask(() {
      notifyListeners();
    });
  }
}
