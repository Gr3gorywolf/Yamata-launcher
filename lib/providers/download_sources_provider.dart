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
  var minMatch = StringHelper.hasMinConsecutiveMatch(
    romNormalizedTitle,
    sourceRomNormalizedTitle,
    minLength: sourceRomNormalizedTitle.length,
  );
  if (minMatch) {
    return true;
  }
  return StringHelper.hasMinConsecutiveMatch(
    sourceRomNormalizedTitle,
    romNormalizedTitle,
    minLength: romNormalizedTitle.length,
  );
}

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
  final Map<String, List<DownloadSource>> result = {};
  Stopwatch stopwatch = new Stopwatch()..start();
  print("Isolate: Compiling download sources for ${payload.roms.length} roms");
  var romConsoles = payload.roms.map((e) => e.console).toSet();

  Map<String, List<DownloadSourceWithDownloads>> sourcesByConsole = {};
  for (final console in romConsoles) {
    sourcesByConsole[console] = payload.sources.map((source) {
      return DownloadSourceWithDownloads(
          sourceInfo: source.sourceInfo,
          downloads: source.downloads!
              .where((sourceRom) => sourceRom.console == console)
              .map((download) {
            download.title_clean = RomService.normalizeRomTitle(
                _removeMisplacedWords(download.title ?? ""));
            return download;
          }).toList());
    }).toList();
  }

  var normalizedRoms = payload.roms.map((rom) {
    rom.name = RomService.normalizeRomTitle(_removeMisplacedWords(rom.name));
    return rom;
  }).toList();
  for (final rom in normalizedRoms) {
    var sourcesForConsole = sourcesByConsole[rom.console];
    if (sourcesForConsole == null) continue;
    for (final source in sourcesForConsole) {
      final hasMatch = source.downloads.any(
          (sourceRom) => _isRomMatch(sourceRom.title_clean ?? "", rom.name));

      if (hasMatch) {
        var foundSource = result[rom.slug];
        if (foundSource == null) {
          result[rom.slug] = [source.sourceInfo!];
          continue;
        }
        result[rom.slug] = [...foundSource, source.sourceInfo];
      } else if (result[rom.slug] == null) {
        result[rom.slug] = [];
      }
    }
  }
  print("Finished compiling download sources in isolate in "
      "${stopwatch.elapsed.inMilliseconds} milliseconds");
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
