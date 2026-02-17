import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/platform_catalog_source.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class ConsoleService {
  static List<PlatformCatalogSource> externalPlatformCatalogs = [];

  static PlatformCatalogSource _processExternalSource(
      PlatformCatalogSource source) {
    source.games = source.games.map((game) {
      game.slug =
          RomService.getRomSlug(source.console?.slug ?? "", game.name ?? "");
      return game;
    }).toList();
    return source;
  }

  static String _getSourceFilePath(PlatformCatalogSource source) {
    return FileSystemService.consoleSourcesPath +
        "/" +
        StringHelper.removeInvalidPathCharacters((source.console.slug ?? "") +
            "-" +
            (source.sourceName ?? "").replaceAll(RegExp(r'\s+'), '_')) +
        ".json";
  }

  static Future deleteConsoleSource(PlatformCatalogSource source) async {
    externalPlatformCatalogs
        .removeWhere((element) => element.console.slug == source.console.slug);
    File sourceFile = File(_getSourceFilePath(source));
    if (await sourceFile.exists()) {
      await sourceFile.delete();
    }
  }

  static String? validatePlatformCatalogSource(PlatformCatalogSource source) {
    if (source.downloadUrl == null || source.downloadUrl!.isEmpty) {
      return "Download URL cannot be empty.";
    }
    if (source.sourceName == null || source.sourceName!.isEmpty) {
      return "Source name cannot be empty.";
    }
    if (source.console.slug == null || source.console.slug!.isEmpty) {
      return "Console slug cannot be empty.";
    }
    if (source.console.name == null || source.console.name!.isEmpty) {
      return "Console name cannot be empty.";
    }
    return null;
  }

  static Future<PlatformCatalogSource?> getConsoleSource(
      PlatformCatalogSource source) async {
    File consoleFile = File(_getSourceFilePath(source));
    if (await consoleFile.exists()) {
      String jsonString = await consoleFile.readAsString();
      var consoleSource =
          PlatformCatalogSource.fromJson(json.decode(jsonString));
      return consoleSource;
    }
    return null;
  }

  static Future<bool> addConsoleSource(PlatformCatalogSource source) async {
    File consoleFile = File(_getSourceFilePath(source));
    if (consoleFile.existsSync()) {
      return false;
    }

    var processedSource = _processExternalSource(source);
    externalPlatformCatalogs.add(processedSource);
    String jsonString = json.encode(_processExternalSource(source).toJson());
    await consoleFile.writeAsString(jsonString);
    return true;
  }

  static Future<bool> updateConsoleSource(PlatformCatalogSource source) async {
    File consoleFile = File(_getSourceFilePath(source));
    if (!consoleFile.existsSync()) {
      return false;
    }
    var index = externalPlatformCatalogs
        .indexWhere((element) => element.downloadUrl == source.downloadUrl);
    externalPlatformCatalogs[index] = _processExternalSource(source);

    String jsonString = json.encode(_processExternalSource(source).toJson());
    await consoleFile.writeAsString(jsonString);
    return true;
  }

  static Future loadConsoleSources() async {
    externalPlatformCatalogs = [];
    Directory consoleSourcesDir =
        Directory(FileSystemService.consoleSourcesPath);
    if (await consoleSourcesDir.exists()) {
      var consoleFiles = consoleSourcesDir.listSync();
      for (var file in consoleFiles) {
        if (file.path.endsWith(".json")) {
          String jsonString = await File(file.path).readAsString();
          var consoleSource =
              PlatformCatalogSource.fromJson(json.decode(jsonString));
          var validationError = validatePlatformCatalogSource(consoleSource);
          if (validationError != null) {
            print(
                "Invalid console source '${consoleSource.sourceName}': $validationError. Skipping.");
            continue;
          }

          externalPlatformCatalogs.add(_processExternalSource(consoleSource));
        }
      }
    }
  }

  static String getConsoleVendor(Console console) {
    if (console.vendor != null && console.vendor!.isNotEmpty) {
      return console.vendor!;
    }
    var additional = ConsoleConstants.additionalConsoles
        .firstWhere((c) => c.slug == console.slug, orElse: () => Console());
    return additional.vendor ?? "Other";
  }

  static Console _getMergedConsole(Console existing, Console newConsole) {
    String? getNonEmptyStringValue(String? a, String? b) {
      if (a != null && a.isNotEmpty) return a;
      if (b != null && b.isNotEmpty) return b;
      return null;
    }

    return Console(
      name: getNonEmptyStringValue(existing.name, newConsole.name),
      altName: getNonEmptyStringValue(existing.altName, newConsole.altName),
      slug: getNonEmptyStringValue(existing.slug, newConsole.slug),
      vendor: getNonEmptyStringValue(existing.vendor, newConsole.vendor),
      description:
          getNonEmptyStringValue(existing.description, newConsole.description),
      logoUrl: getNonEmptyStringValue(existing.logoUrl, newConsole.logoUrl),
    );
  }

  static List<Console> getConsoles({bool includeUnsupported = false}) {
    var officialConsolesMap = <String, Console>{};
    for (var console in ConsoleConstants.defaultConsoles) {
      officialConsolesMap[console.slug ?? ""] = console;
    }

    var additionalConsolesMap = <String, Console>{};
    for (var console in ConsoleConstants.additionalConsoles) {
      additionalConsolesMap[console.slug ?? ""] = console;
    }

    var uniqueConsoles = <String, Console>{};
    uniqueConsoles.addAll(officialConsolesMap);
    if (includeUnsupported) {
      uniqueConsoles.addAll(additionalConsolesMap);
    }

    // Merges the external platform catalogs to be just one console entry per slug
    var externalPlatformSources =
        externalPlatformCatalogs.map((source) => source.console);
    var uniqueExternalPlatformCatalogs = <String, Console>{};
    for (var console in externalPlatformSources) {
      var foundConsole = uniqueConsoles[console.slug];
      //If found a built in console with the same slug just merge the external data
      if (foundConsole != null) {
        uniqueExternalPlatformCatalogs[console.slug ?? ""] =
            _getMergedConsole(foundConsole, console);
      } else {
        var existingAdditional = additionalConsolesMap[console.slug];
        uniqueExternalPlatformCatalogs[console.slug ?? ""] =
            existingAdditional != null
                ? _getMergedConsole(existingAdditional, console)
                : console;
      }
    }
    uniqueConsoles.addAll(uniqueExternalPlatformCatalogs);
    return uniqueConsoles.values.toList();
  }

  static Console? getConsoleFromName(String? name) {
    var consoles = getConsoles(includeUnsupported: true);
    var results = consoles.where((element) =>
        element.altName == name ||
        element.name == name ||
        element.slug == name);
    if (results.isEmpty) {
      return null;
    } else {
      return results.first;
    }
  }
}
