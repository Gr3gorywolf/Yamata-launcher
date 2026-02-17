import 'dart:convert';
import 'dart:io';

import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/models/console.dart';
import 'package:yamata_launcher/models/platform_catalog_source.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class ConsoleService {
  static List<PlatformCatalogSource> externalplatformCatalogs = [];

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
    externalplatformCatalogs
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
    externalplatformCatalogs.add(processedSource);
    String jsonString = json.encode(_processExternalSource(source).toJson());
    await consoleFile.writeAsString(jsonString);
    return true;
  }

  static Future<bool> updateConsoleSource(PlatformCatalogSource source) async {
    File consoleFile = File(_getSourceFilePath(source));
    if (!consoleFile.existsSync()) {
      return false;
    }
    var index = externalplatformCatalogs
        .indexWhere((element) => element.downloadUrl == source.downloadUrl);
    externalplatformCatalogs[index] = _processExternalSource(source);

    String jsonString = json.encode(_processExternalSource(source).toJson());
    await consoleFile.writeAsString(jsonString);
    return true;
  }

  static Future loadConsoleSources() async {
    externalplatformCatalogs = [];
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

          externalplatformCatalogs.add(_processExternalSource(consoleSource));
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

  static List<Console> getConsoles(
      {bool unique = false, bool includeAdditional = false}) {
    var allConsoles = [
      ...ConsoleConstants.defaultConsoles,
      ...externalplatformCatalogs.map((source) => source.console),
    ];
    if (includeAdditional) {
      allConsoles.addAll(ConsoleConstants.additionalConsoles);
    }
    if (!unique) {
      return allConsoles;
    }
    var uniqueConsoles = <String, Console>{};
    String? getNonEmptyStringValue(String? a, String? b) {
      if (a != null && a.isNotEmpty) return a;
      if (b != null && b.isNotEmpty) return b;
      return null;
    }

    Console getMergedConsole(Console existing, Console newConsole) {
      return Console(
        name: getNonEmptyStringValue(newConsole.name, existing.name),
        altName: getNonEmptyStringValue(newConsole.altName, existing.altName),
        slug: getNonEmptyStringValue(newConsole.slug, existing.slug),
        vendor: getNonEmptyStringValue(newConsole.vendor, existing.vendor),
        description: getNonEmptyStringValue(
            newConsole.description, existing.description),
        logoUrl: getNonEmptyStringValue(newConsole.logoUrl, existing.logoUrl),
      );
    }

    for (var console in allConsoles) {
      if (uniqueConsoles[console.slug ?? ""] != null) {
        var existing = uniqueConsoles[console.slug ?? ""];
        uniqueConsoles[console.slug ?? ""] =
            existing != null ? getMergedConsole(existing, console) : console;
        continue;
      }
      if (console.vendor == null || console.vendor!.isEmpty) {
        console.vendor = getConsoleVendor(console);
      }
      uniqueConsoles[console.slug ?? ""] = console;
    }
    return uniqueConsoles.values.toList();
  }

  static Console? getConsoleFromName(String? name) {
    var consoles = getConsoles(includeAdditional: true);
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
