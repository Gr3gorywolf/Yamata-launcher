import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';

import 'package:yamata_launcher/services/download_sources_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class _CompilePayload {
  final List<RomInfo> roms;
  final _CompiledSourceIndex sourceIndex;

  _CompilePayload({
    required this.roms,
    required this.sourceIndex,
  });
}

class _CompiledSourceIndex {
  final Map<String, DownloadSource> sourceInfoByKey;
  final Map<String, Map<String, Map<String, List<String>>>>
      titleSourcesByConsolePrefix;
  final Map<String, Map<String, List<String>>> sourceOrderByConsolePrefix;

  _CompiledSourceIndex({
    required this.sourceInfoByKey,
    required this.titleSourcesByConsolePrefix,
    required this.sourceOrderByConsolePrefix,
  });
}

bool _isRomMatch(
  String sourceRomNormalizedTitle,
  String romNormalizedTitle,
) {
  if (sourceRomNormalizedTitle.isEmpty || romNormalizedTitle.isEmpty) {
    return false;
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

  return long.contains(short);
}

String _prefix3(String s) => s.length <= 3 ? s : s.substring(0, 3);

String _normalizeTitleForMatching(String input) {
  return RomService.normalizeRomTitle(
    StringHelper.removeMisplacedWords(input),
    deleteRunes: true,
  );
}

bool _isRomMatchInSamePrefixBucket(
  String sourceRomNormalizedTitle,
  String romNormalizedTitle,
) {
  if (sourceRomNormalizedTitle.isEmpty || romNormalizedTitle.isEmpty) {
    return false;
  }

  final short = sourceRomNormalizedTitle.length <= romNormalizedTitle.length
      ? sourceRomNormalizedTitle
      : romNormalizedTitle;

  final long = sourceRomNormalizedTitle.length > romNormalizedTitle.length
      ? sourceRomNormalizedTitle
      : romNormalizedTitle;

  return long.contains(short);
}

String _getSourceKey(DownloadSource sourceInfo, int sourceIndex) {
  final downloadUrl = sourceInfo.downloadUrl?.trim();
  if (downloadUrl != null && downloadUrl.isNotEmpty) {
    return downloadUrl;
  }

  return "${sourceInfo.title}#$sourceIndex";
}

DownloadSourceWithDownloads _prepareSourceForMatching(
  DownloadSourceWithDownloads source,
) {
  source.downloads = (source.downloads ?? const []).map((download) {
    download.titleClean = _normalizeTitleForMatching(download.title ?? "");
    return download;
  }).toList();

  return source;
}

_CompiledSourceIndex _buildCompiledSourceIndexIsolate(
  List<DownloadSourceWithDownloads> sources,
) {
  final sourceInfoByKey = <String, DownloadSource>{};
  final titleSourcesByConsolePrefix =
      <String, Map<String, Map<String, List<String>>>>{};
  final sourceOrderByConsolePrefix = <String, Map<String, List<String>>>{};

  for (var sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
    final source = sources[sourceIndex];
    final sourceKey = _getSourceKey(source.sourceInfo, sourceIndex);
    sourceInfoByKey[sourceKey] = source.sourceInfo;

    final seenBuckets = <String>{};
    final seenTitles = <String>{};

    for (final download in source.downloads ?? const []) {
      final console = download.console ?? "";
      if (console.isEmpty) continue;

      final normalizedTitle = download.titleClean?.isNotEmpty == true
          ? download.titleClean!
          : _normalizeTitleForMatching(download.title ?? "");

      if (normalizedTitle.isEmpty) continue;

      final prefix = _prefix3(normalizedTitle);
      final bucketKey = "$console|$prefix";
      final titleKey = "$bucketKey|$normalizedTitle";

      final consoleTitleMap =
          titleSourcesByConsolePrefix.putIfAbsent(console, () => {});
      final titleMap = consoleTitleMap.putIfAbsent(prefix, () => {});

      final consoleSourceOrder =
          sourceOrderByConsolePrefix.putIfAbsent(console, () => {});
      final sourceOrder = consoleSourceOrder.putIfAbsent(prefix, () => []);

      if (seenBuckets.add(bucketKey)) {
        sourceOrder.add(sourceKey);
      }

      if (!seenTitles.add(titleKey)) {
        continue;
      }

      final sourceKeysForTitle =
          titleMap.putIfAbsent(normalizedTitle, () => []);
      sourceKeysForTitle.add(sourceKey);
    }
  }

  return _CompiledSourceIndex(
    sourceInfoByKey: sourceInfoByKey,
    titleSourcesByConsolePrefix: titleSourcesByConsolePrefix,
    sourceOrderByConsolePrefix: sourceOrderByConsolePrefix,
  );
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
  final romsByConsolePrefixAndName =
      <String, Map<String, Map<String, List<String>>>>{};

  for (final rom in payload.roms) {
    final normalizedName = _normalizeTitleForMatching(rom.name);
    if (normalizedName.isEmpty || rom.console.isEmpty) continue;

    final prefix = _prefix3(normalizedName);
    final consoleMap =
        romsByConsolePrefixAndName.putIfAbsent(rom.console, () => {});
    final romNamesByPrefix = consoleMap.putIfAbsent(prefix, () => {});
    final romSlugs = romNamesByPrefix.putIfAbsent(normalizedName, () => []);
    romSlugs.add(rom.slug);
  }

  print("ROM groups built in ${stopwatch.elapsedMilliseconds} ms");

  for (final consoleEntry in romsByConsolePrefixAndName.entries) {
    final console = consoleEntry.key;
    final indexedPrefixes =
        payload.sourceIndex.titleSourcesByConsolePrefix[console];
    final sourceOrderByPrefix =
        payload.sourceIndex.sourceOrderByConsolePrefix[console];

    if (indexedPrefixes == null || sourceOrderByPrefix == null) continue;

    for (final prefixEntry in consoleEntry.value.entries) {
      final prefix = prefixEntry.key;
      final titlesForPrefix = indexedPrefixes[prefix];
      final sourceOrder = sourceOrderByPrefix[prefix];

      if (titlesForPrefix == null ||
          titlesForPrefix.isEmpty ||
          sourceOrder == null ||
          sourceOrder.isEmpty) {
        continue;
      }

      final titleEntries = titlesForPrefix.entries.toList(growable: false);

      for (final romEntry in prefixEntry.value.entries) {
        final romName = romEntry.key;
        final matchedSourceKeys = <String>{};

        for (final titleEntry in titleEntries) {
          if (_isRomMatchInSamePrefixBucket(titleEntry.key, romName)) {
            matchedSourceKeys.addAll(titleEntry.value);
          }
        }

        if (matchedSourceKeys.isEmpty) {
          continue;
        }

        final matchedSources = <DownloadSource>[];
        for (final sourceKey in sourceOrder) {
          if (matchedSourceKeys.contains(sourceKey)) {
            final sourceInfo = payload.sourceIndex.sourceInfoByKey[sourceKey];
            if (sourceInfo != null) {
              matchedSources.add(sourceInfo);
            }
          }
        }

        if (matchedSources.isEmpty) {
          continue;
        }

        for (final slug in romEntry.value) {
          result[slug] = matchedSources;
        }
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
  final List<String> _sourceUrlsWithUpdates = [];
  final Set<String> _compilingRoms = {};
  _CompiledSourceIndex? _compiledSourceIndex;
  Future<_CompiledSourceIndex>? _compiledSourceIndexFuture;
  bool _initialized = false;
  int _version = 0;

  List<DownloadSourceWithDownloads> get downloadSources => _downloadSources;
  List<String> get sourceUrlsWithUpdates => _sourceUrlsWithUpdates;
  bool get initialized => _initialized;
  int get version => _version;

  @override
  void notifyListeners() {
    _version++;
    super.notifyListeners();
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _downloadSources = (await DownloadSourcesService.getDownloadSources())
        .map(_prepareSourceForMatching)
        .toList();
    _invalidateCompiledIndex();
    checkForUpdates();
    Timer.periodic(const Duration(hours: 1), (_) async {
      await checkForUpdates();
    });
    _initialized = true;
    notifyListeners();
  }

  checkForUpdates() async {
    print("Checking for download source updates...");
    var updates = await DownloadSourcesRepository().fetchDownloadSourcesUpdates(
        _downloadSources.map((s) => s.sourceInfo).toList());
    _sourceUrlsWithUpdates.clear();
    _sourceUrlsWithUpdates.addAll(updates);
    print("Found ${updates.length} updates");
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
    final normalizedRomName = _normalizeTitleForMatching(rom.name);

    return source.downloads
        .where((sourceRom) =>
            sourceRom.console == rom.console &&
            _isRomMatch(
              sourceRom.titleClean?.isNotEmpty == true
                  ? sourceRom.titleClean!
                  : _normalizeTitleForMatching(sourceRom.title ?? ""),
              normalizedRomName,
            ))
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

    try {
      final sourceIndex = await _getCompiledSourceIndex();
      final payload = _CompilePayload(
        roms: romsToCompile,
        sourceIndex: sourceIndex,
      );
      final Map<String, List<DownloadSource>> compiled =
          await compute(_compileRomSourcesIsolate, payload);
      _romSources.addAll(compiled);
    } finally {
      _compilingRoms.removeAll(romsToCompile.map((e) => e.slug));
      notifyListeners();
    }
  }

  Future<bool> setDownloadSource(DownloadSourceWithDownloads source) async {
    final parsed = _prepareSourceForMatching(
        DownloadSourcesService.parseDownloadSourceNames(
      source,
    ));

    final validFile = await DownloadSourcesService.saveDownloadSource(parsed);

    if (!validFile) return false;

    final index = _downloadSources.indexWhere(
      (s) => s.sourceInfo.downloadUrl == parsed.sourceInfo!.downloadUrl,
    );

    if (index != -1) {
      _downloadSources[index] = parsed;
    } else {
      _downloadSources.add(parsed);
    }

    _romSources.clear();
    _invalidateCompiledIndex();
    notifyListeners();
    return true;
  }

  void removeDownloadSource(DownloadSourceWithDownloads source) {
    _downloadSources.remove(source);
    _romSources.clear();
    _invalidateCompiledIndex();
    DownloadSourcesService.deleteDownloadSource(source);
    notifyListeners();
  }

  void _invalidateCompiledIndex() {
    _compiledSourceIndex = null;
    _compiledSourceIndexFuture = null;
  }

  Future<_CompiledSourceIndex> _getCompiledSourceIndex() async {
    if (_compiledSourceIndex != null) {
      return _compiledSourceIndex!;
    }

    if (_compiledSourceIndexFuture != null) {
      return _compiledSourceIndexFuture!;
    }

    _compiledSourceIndexFuture =
        compute<List<DownloadSourceWithDownloads>, _CompiledSourceIndex>(
      _buildCompiledSourceIndexIsolate,
      List<DownloadSourceWithDownloads>.unmodifiable(_downloadSources),
    );

    try {
      _compiledSourceIndex = await _compiledSourceIndexFuture!;
      return _compiledSourceIndex!;
    } finally {
      _compiledSourceIndexFuture = null;
    }
  }
}
