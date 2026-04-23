import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/launchbox_registry.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_metadata.dart';
import 'package:yamata_launcher/models/tgdb.dart';
import 'package:yamata_launcher/services/extraction_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/services/scrapers/metadata/launchbox_scraper.dart';
import 'package:yamata_launcher/services/scrapers/metadata/steamgrid_scraper.dart';
import 'package:yamata_launcher/services/scrapers/metadata/tgdb_scraper.dart';
import 'package:yamata_launcher/utils/file_download_fetch.dart';

enum ArtworkProviders {
  LAUNCHBOX("Launchbox gamedb"),
  TGDB("TheGamesDB"),
  SGDB("Steam GridDB (Needs API key)");

  final String value;
  const ArtworkProviders(this.value);
}

enum ArtType {
  portrait,
  gameplay,
}

class GameMetadataRepository {
  static Future<List<String>?> fetchArtworkFromProvider(
      ArtworkProviders provider, ArtType artType, String gameName) async {
    switch (provider) {
      case ArtworkProviders.LAUNCHBOX:
        {
          var results = await LaunchboxScraper().search(gameName);
          var artworkTypeMap = {
            ArtType.portrait: (List<RomInfo> details) =>
                details.map((e) => e.portrait).whereType<String>().toList(),
            ArtType.gameplay: (List<RomInfo> details) => details
                .map((e) => e.gameplayCovers)
                .whereType<String>()
                .toList(),
          };
          return artworkTypeMap[artType]?.call(results) ?? [];
        }

      case ArtworkProviders.TGDB:
        {
          var results = await TheGamesDbScraper().search(gameName, null);
          var artworkTypeMap = {
            ArtType.portrait: (List<TgdbSearchResult> details) =>
                details.map((e) => e.thumbnail).whereType<String>().toList(),
          };
          if (!artworkTypeMap.containsKey(artType)) {
            return [];
          }
          return artworkTypeMap[artType]?.call(results) ?? [];
        }
        ;
      case ArtworkProviders.SGDB:
        {
          var artworkTypeMap = {
            ArtType.portrait: SteamGridArtType.grids,
            ArtType.gameplay: SteamGridArtType.heroes,
          };
          throw Exception("No api key provided for SteamGridDB");
          var res = await SteamGridScraper(apiKey: "")
              .search(gameName, artworkTypeMap[artType]!);
          return res.map((art) => art.url).toList();
        }
    }
  }

  // This method checks if the metadata build is already downloaded and up to date by comparing the content length of the remote file with the local registry file.
  //If the local files are missing or outdated, it downloads the new build, extracts it, and prepares the metadata for use. It returns true if the metadata is ready to use,
  //or false if there was an error during the process.
  static Future<bool> prepareMetadataBuild() async {
    var registryFile =
        File(FileSystemService.metadatasPath + "/${DOWNLOAD_MARK_FILENAME}");
    int? contentLength = null;
    try {
      var res = await Dio()
          .head(AppConstants.libretroMetadatasLastRelease + "/build.zip");
      contentLength = res.headers.value("content-length") != null
          ? int.tryParse(res.headers.value("content-length")!)
          : null;
    } catch (e) {
      print("Error while checking metadata build existence: $e");
    }

    if (registryFile.existsSync()) {
      var registryContentLength = int.tryParse(registryFile.readAsStringSync());
      var hasAllRequiredFiles = METADATA_REQUIRED_FILES.every((file) =>
          File(FileSystemService.metadatasPath + "/" + file).existsSync());
      var contentLengthMatch =
          contentLength != null && registryContentLength != null
              ? contentLength == registryContentLength
              : true;
      if (hasAllRequiredFiles && contentLengthMatch) {
        print("Metadata build is up to date, skipping download.");
        return true;
      }
    }

    print("Downloading metadata build...");
    try {
      var hasError = false;
      await FileDownloadFetch(
          url: Uri.parse(
              AppConstants.libretroMetadatasLastRelease + "/build.zip"),
          savePath: FileSystemService.metadatasPath + "/build.zip",
          onCancelled: () {
            print("Metadata build download cancelled.");
            hasError = true;
          },
          onProgress: (progress) {
            print("Download progress: $progress%");
          }).start();

      if (hasError) {
        return false;
      }
      // Unzip the downloaded file
      var inputFile = File(FileSystemService.metadatasPath + "/build.zip");
      if (!inputFile.existsSync()) {
        print("Downloaded metadata build not found.");
        return false;
      }
      try {
        await ExtractionService.extractWithArchive(
            inputFile, Directory(FileSystemService.metadatasPath),
            deleteArchive: true);
      } catch (e) {
        print("Error while accessing downloaded metadata build: $e");
        return false;
      }
    } catch (e) {
      print("Error while downloading metadata build: $e");
      return false;
    }
    if (contentLength != null) {
      registryFile.writeAsStringSync(contentLength.toString());
    }

    return true;
  }

  static Future<List<LaunchboxRegistry>> fetchLaunchboxIndex() async {
    final path = FileSystemService.metadatasPath + "/libretro-index.json";

    return await Isolate.run(() async {
      final file = File(path);

      if (!file.existsSync()) {
        throw Exception("Metadata registry file not found.");
      }

      final content = jsonDecode(await file.readAsString());

      final List<LaunchboxRegistry> registries = [];

      for (final item in content) {
        registries.add(LaunchboxRegistry.fromJson(item));
      }

      return registries;
    });
  }

  static Future<Map<String, List<RomMetadata>>> retrieveMetadataIndexByType(
      RomMetadataLookups lookup, String metadatasPath) async {
    Map<String, List<RomMetadata>> metadatas = {};
    var filesByLookups = <RomMetadataLookups, String>{
      RomMetadataLookups.FILE_SIZE: "all-sizes.json",
      RomMetadataLookups.EXEC_NAME: "all-execs.json",
      RomMetadataLookups.SERIAL: "all-serials.json",
      RomMetadataLookups.SLUG: "libretro-full-database.json",
    };

    var fileName = filesByLookups[lookup];
    if (fileName == null) {
      throw Exception(
          "No metadata index file defined for lookup type ${lookup.value}");
    }

    var registryFile = File(metadatasPath + "/${fileName}");
    if (!registryFile.existsSync()) {
      throw Exception(
          "Metadata index file not found for lookup type ${lookup.value}");
    }
    var content = jsonDecode(registryFile.readAsStringSync());
    // For execs registries
    if (lookup == RomMetadataLookups.EXEC_NAME) {
      for (var exec in content) {
        var execName = exec["exec"];
        if (execName == null) {
          continue;
        }
        var execParts = [execName];
        if (execName.contains("/")) {
          execParts.add(execName.split("/").last);
        }
        for (var part in execParts) {
          if (!metadatas.containsKey(part)) {
            metadatas[part] = [];
          }
          metadatas[part]
              ?.add(RomMetadata(name: exec['name'], console: "windows"));
        }
      }
    }
    if ([RomMetadataLookups.SERIAL, RomMetadataLookups.FILE_SIZE]
        .contains(lookup)) {
      content.forEach((key, value) {
        final list = value as List;

        metadatas[key] = List<RomMetadata>.generate(
          list.length,
          (i) {
            var item = list[i];
            if (RomMetadataLookups.SLUG == lookup) {
              var newMetadata = RomMetadata(
                  name: item['name'],
                  console: item['console'],
                  info: RomInfo.fromJson(item));
              return newMetadata;
            }
            return RomMetadata.fromJson(item);
          },
          growable: false,
        );
      });
    }

    if (lookup == RomMetadataLookups.SLUG) {
      content.forEach((_, value) {
        final list = value as List;

        for (var i = 0; i < list.length; i++) {
          final itemJson = list[i];

          final rom = RomMetadata(
              name: itemJson['name'],
              console: itemJson['console'],
              info: RomInfo.fromJson(itemJson));
          final slug = rom.info?.slug;
          if (slug == null) {
            continue;
          }
          var composedSlug = RomService.getRomSlug(
              itemJson['console'], itemJson['name'],
              removeMisplacedWords: true);

          var slugsToInsert = [slug];
          if (composedSlug != slug) {
            slugsToInsert.add(composedSlug);
          }
          for (var slugToInsert in slugsToInsert) {
            final existing = metadatas[slugToInsert];
            if (existing != null) {
              existing.add(rom);
            } else {
              metadatas[slugToInsert] = [rom];
            }
          }
        }
      });
    }

    return metadatas;
  }
}
