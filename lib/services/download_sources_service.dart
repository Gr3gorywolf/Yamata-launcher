import 'dart:convert';
import 'dart:io';

import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/services/cache_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

const sourcesFile = "download-sources.json";

class DownloadSourcesService {
  static Future cacheDownloadSources(Map<String, List<String>> sources) async {
    try {
      final jsonData = json.encode(sources.map((key, value) =>
          MapEntry(key, value.map((e) => e.toString()).toList())));
      await CacheService.writeCacheFile(
        sourcesFile,
        jsonData,
      );
    } catch (e) {
      print("Error caching download sources: $e");
    }
  }

  static Future<Map<String, List<String>>?> getCachedDownloadSources() async {
    try {
      final cachedData = await CacheService.retrieveCacheFile(sourcesFile);
      if (cachedData != null) {
        final Map<String, dynamic> decodedData = json.decode(cachedData);
        return decodedData.map((key, value) =>
            MapEntry(key, (value as List).map((e) => e as String).toList()));
      }
    } catch (e) {
      print("Error retrieving cached download sources: $e");
    }
    return null;
  }

  static String _getDownloadSourcePath(DownloadSourceWithDownloads source) {
    return FileSystemService.downloadSourcesPath +
        "/" +
        StringHelper.removeInvalidPathCharacters(
            source.sourceInfo.title.replaceAll(RegExp(r'\s+'), '_')) +
        ".json";
  }

  static Future<List<DownloadSourceWithDownloads>> getDownloadSources() async {
    List<DownloadSourceWithDownloads> downloadSources = [];
    var files = Directory(FileSystemService.downloadSourcesPath)
        .listSync()
        .whereType<File>()
        .toList();
    for (var file in files) {
      if (file.path.endsWith(".json")) {
        var content = await file.readAsString();
        var source = DownloadSourceWithDownloads.fromJson(
            json.decode(content) as Map<String, dynamic>);
        downloadSources.add(source);
      }
    }
    return downloadSources;
  }

  static DownloadSourceWithDownloads parseDownloadSourceNames(
      DownloadSourceWithDownloads input) {
    input.downloads = input.downloads!.map((e) {
      e.titleClean = RomService.normalizeRomTitle(e.title!);

      return e;
    }).toList();
    return input;
  }

  static Future<bool> saveDownloadSource(
      DownloadSourceWithDownloads source) async {
    final jsonData = json.encode(source.toJson());
    final file = File(_getDownloadSourcePath(source));
    await file.writeAsString(jsonData);
    return true;
  }

  static Future<void> deleteDownloadSource(
      DownloadSourceWithDownloads source) async {
    final file = File(_getDownloadSourcePath(source));
    if (await file.exists()) {
      await file.delete();
    }
  }
}
