import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/models/rom_info.dart';

import 'package:yamata_launcher/services/download_sources_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class _CompilePayload {
  final List<RomInfo> roms;
  final List<DownloadSourceWithDownloads> sources;

  _CompilePayload({
    required this.roms,
    required this.sources,
  });
}

bool _isRomMatch(
  String sourceRomNormalizedTitle,
  String romNormalizedTitle,
) {
  if (sourceRomNormalizedTitle.isEmpty || romNormalizedTitle.isEmpty)
    return false;

  if (sourceRomNormalizedTitle == romNormalizedTitle) {
    return true;
  }
  if (sourceRomNormalizedTitle[0] != romNormalizedTitle[0]) {
    return false;
  }

  final short = sourceRomNormalizedTitle.length <= romNormalizedTitle.length
      ? sourceRomNormalizedTitle
      : romNormalizedTitle;

  final long = sourceRomNormalizedTitle.length > romNormalizedTitle.length
      ? sourceRomNormalizedTitle
      : romNormalizedTitle;
  var minMatch =
      StringHelper.hasMinConsecutiveMatch(long, short, minLength: short.length);
  return minMatch;
}

String _prefix3(String s) => s.length <= 3 ? s : s.substring(0, 3);

/**
 * Remove words that are commonly misplaced in titles to improve matching accuracy.
 */
String _removeMisplacedWords(String input) {
  var wordsToRemove = ["the", "and", "of"];
  var pattern =
      RegExp(r'\b(' + wordsToRemove.join('|') + r')\b', caseSensitive: false);
  return input.replaceAll(pattern, '').trim();
}

/**
 * Isolate function to compile download sources for roms.
 */
Map<String, List<DownloadSource>> _compileRomSourcesIsolate(
  _CompilePayload payload,
) {
  final result = <String, List<DownloadSource>>{};
  final stopwatch = Stopwatch()..start();

  print("Isolate: Compiling ${payload.roms.length} roms");

  for (final rom in payload.roms) {
    rom.name = RomService.normalizeRomTitle(
      _removeMisplacedWords(rom.name),
    );
  }

  final Map<String, Map<String, List<DownloadSourceWithDownloads>>> index = {};

  for (final source in payload.sources) {
    for (final d in source.downloads ?? const []) {
      final console = d.console;

      d.titleClean ??= RomService.normalizeRomTitle(
        _removeMisplacedWords(d.title ?? ""),
      );

      if (d.titleClean!.isEmpty) continue;

      final prefix = _prefix3(d.titleClean!);

      final consoleMap = index.putIfAbsent(console, () => {});
      final list = consoleMap.putIfAbsent(prefix, () => []);

      DownloadSourceWithDownloads? wrapper;
      for (final s in list) {
        if (s.sourceInfo == source.sourceInfo) {
          wrapper = s;
          break;
        }
      }

      wrapper ??= DownloadSourceWithDownloads(
        sourceInfo: source.sourceInfo,
        downloads: [],
      );

      if (!list.contains(wrapper)) {
        list.add(wrapper);
      }

      wrapper.downloads.add(d);
    }
  }

  print("Index built in ${stopwatch.elapsedMilliseconds} ms");

  for (final rom in payload.roms) {
    final name = rom.name;
    if (name.isEmpty) continue;

    final consoleMap = index[rom.console];
    if (consoleMap == null) continue;

    final prefix = _prefix3(name);
    final candidates = consoleMap[prefix];
    if (candidates == null) continue;

    final romResult = result.putIfAbsent(rom.slug, () => []);

    for (final source in candidates) {
      if (source.downloads.any(
        (d) => _isRomMatch(d.titleClean!, name),
      )) {
        romResult.add(source.sourceInfo!);
      }
    }
  }

  print("Finished in ${stopwatch.elapsedMilliseconds} ms");

  return result;
}

class DownloadSourcesProvider extends ChangeNotifier {
  static DownloadSourcesProvider of(BuildContext ctx) {
    return Provider.of<DownloadSourcesProvider>(ctx);
  }

  List<DownloadSourceWithDownloads> _downloadSources = [];
  final Map<String, List<DownloadSource>> _romSources = {};
  final Set<String> _compilingRoms = {};
  bool _initialized = false;

  List<DownloadSourceWithDownloads> get downloadSources => _downloadSources;
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    _downloadSources = await DownloadSourcesService.getDownloadSources();
    _initialized = true;
    notifyListeners();
  }

  bool isRomCompilingDownloadSources(String romSlug) {
    return _compilingRoms.contains(romSlug);
  }

  List<String> get downloadSourcesPasswords {
    final passwords = <String>{};
    for (final source in _downloadSources) {
      if (source.sourceInfo.passwords != null) {
        passwords.addAll(source.sourceInfo.passwords!);
      }
    }
    return passwords.toList();
  }

  List<DownloadSource> getRomSources(String romSlug) {
    return _romSources[romSlug] ?? [];
  }

  List<DownloadSourceRom> _findMatches(
    DownloadSourceWithDownloads source,
    RomInfo rom,
  ) {
    final normalizedRomName =
        RomService.normalizeRomTitle(_removeMisplacedWords(rom.name));

    return source.downloads
        .where((sourceRom) =>
            sourceRom.console == rom.console &&
            _isRomMatch(
                RomService.normalizeRomTitle(
                    _removeMisplacedWords(sourceRom.title ?? "")),
                normalizedRomName))
        .toList();
  }

  List<DownloadSourceWithDownloads> findRomSourcesWithDownloads(RomInfo rom) {
    return _downloadSources
        .map((source) {
          final matches = _findMatches(source, rom);
          if (matches.isEmpty) return null;

          return DownloadSourceWithDownloads(
            sourceInfo: source.sourceInfo,
            downloads: matches,
          );
        })
        .whereType<DownloadSourceWithDownloads>()
        .toList();
  }

  Future<void> compileRomDownloadSources(List<RomInfo> roms) async {
    if (_downloadSources.isEmpty || roms.isEmpty) return;

    final romsToCompile =
        roms.where((rom) => _romSources[rom.slug] == null).toList();

    if (romsToCompile.isEmpty) return;
    _compilingRoms.addAll(romsToCompile.map((e) => e.slug));
    notifyListeners();
    final payload = _CompilePayload(
      roms: romsToCompile,
      sources: List.unmodifiable(_downloadSources),
    );
    final Map<String, List<DownloadSource>> compiled =
        await compute(_compileRomSourcesIsolate, payload);
    _romSources.addAll(compiled);
    _compilingRoms.removeAll(romsToCompile.map((e) => e.slug));
    notifyListeners();
  }

  Future<bool> setDownloadSource(DownloadSourceWithDownloads source) async {
    final parsed = DownloadSourcesService.parseDownloadSourceNames(source);

    final validFile = await DownloadSourcesService.saveDownloadSource(parsed);

    if (!validFile) return false;

    final index = _downloadSources.indexWhere(
      (s) => s.sourceInfo.title == parsed.sourceInfo!.title,
    );

    if (index != -1) {
      _downloadSources[index] = parsed;
    } else {
      _downloadSources.add(parsed);
    }

    _romSources.clear();
    notifyListeners();
    return true;
  }

  void removeDownloadSource(DownloadSourceWithDownloads source) {
    _downloadSources.remove(source);
    _romSources.clear();
    DownloadSourcesService.deleteDownloadSource(source);
    notifyListeners();
  }
}
