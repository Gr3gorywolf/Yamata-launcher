import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/library_dao.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/utils/cached_fetch.dart';
import 'package:yamata_launcher/utils/plain_text_search.dart';

import '../providers/library_provider.dart';

class RomsRepository {
  Future<List<RomInfo>> fetchRoms(Console console) async {
    Map<String, RomInfo> roms = {};
    final url = "${AppConstants.apiBasePath}/Data/Roms/${console.slug}.json";
    var externalConsoles = ConsoleService.externalplatformCatalogs;
    var foundExternalSources =
        externalConsoles.where((c) => c.console.slug == console.slug).toList();
    final result =
        await CachedFetch.withContentLengthSignature<Map<String, RomInfo>>(
      key: console.slug ?? "unknown_console",
      url: url,
      parser: (json) {
        final Map<String, RomInfo> roms = {};
        for (final rom in json['games']) {
          roms[rom['slug'] ?? ""] = RomInfo.fromJson(rom);
        }
        return roms;
      },
    );

    if (result != null) roms.addAll(result);
    if (foundExternalSources.isNotEmpty) {
      for (var source in foundExternalSources) {
        var consoleSource = await ConsoleService.getConsoleSource(source);
        if (consoleSource == null) continue;

        for (var rom in consoleSource.games) {
          roms[rom.slug ?? ""] = rom;
        }
      }
    }

    return roms.values.toList();
  }

  Future<List<RomInfo>> searchRoms(String query) async {
    var client = new http.Client();
    var searchUrl =
        "${AppConstants.serverBaseUrl}search?q=${Uri.encodeComponent(query)}";
    var res = await client.get(Uri.parse(searchUrl));
    if (res.statusCode == 200) {
      var results = jsonDecode(res.body) as List<dynamic>;
      return results.map<RomInfo>((json) => RomInfo.fromJson(json)).toList();
    } else {
      return [];
    }
  }

  Future<List<RomInfo>> searchFromExternalSources(String query) async {
    var externalConsoles = ConsoleService.externalplatformCatalogs;
    var allRoms = <RomInfo>[];
    if (externalConsoles.isNotEmpty) {
      for (var console in externalConsoles) {
        var consoleSource = await ConsoleService.getConsoleSource(console);
        if (consoleSource == null) continue;
        for (var rom in consoleSource.games) {
          allRoms.add(rom);
        }
      }
    }
    var romTitles = allRoms.map((rom) => rom.name ?? "").toList();
    var searchResults =
        PlainTextSearch.search(query, romTitles).map((e) => e.item).toList();
    print(searchResults);
    print("Found ${searchResults.length} roms from external sources");
    return allRoms.where((rom) => searchResults.contains(rom.name)).toList();
  }

  Future<List<RomInfo>> getImportedRoms(String query) async {
    if (db == null) return [];
    var importedRoms = await LibraryDao(db!).getImported();

    var importedRomsTitles =
        importedRoms.map((rom) => rom?.rom.name ?? "").toList();
    var importedRomsResults = PlainTextSearch.search(query, importedRomsTitles)
        .map((res) => res.item)
        .toList();
    print(importedRomsResults);
    return importedRoms
        .where(
            (libraryRom) => importedRomsResults.contains(libraryRom.rom.name))
        .toList()
        .map((e) => e.rom)
        .toList();
  }

  Future<RomInfo?> fetchRomDetails(String infoLink) async {
    var client = new http.Client();
    var res = await client.get(Uri.parse(infoLink));
    if (res.statusCode == 200) {
      return RomInfo.fromJson(json.decode(res.body));
    } else {
      return null;
    }
  }

  Future<List<String>> fetchWindowsExecutableNames() async {
    const url =
        "https://raw.githubusercontent.com/Roblox-Thot/discord-activitys/refs/heads/main/json/executables.json";
    final result = await CachedFetch.withContentLengthSignature<List<String>>(
        key: "executables",
        url: url,
        parser: (json) {
          List<String> executables = [];
          for (final item in json) {
            if (REDIST_FILE_MATCHES
                .where((match) => item.toLowerCase().contains(match))
                .isNotEmpty) {
              continue;
            }
            var executableName =
                item.contains("/") ? item.split("/").last : item;
            executables.add(executableName.toLowerCase());
          }
          return executables;
        },
        timeout: Duration(seconds: 10));
    return result ?? [];
  }
}
