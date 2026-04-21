import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/models/launchbox_registry.dart';
import 'package:yamata_launcher/models/rom_metadata.dart';
import 'package:yamata_launcher/services/extraction_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/utils/file_download_fetch.dart';

class GameMetadataRepository {
  // This method checks if the metadata build is already downloaded and up to date by comparing the content length of the remote file with the local registry file.
  //If the local files are missing or outdated, it downloads the new build, extracts it, and prepares the metadata for use. It returns true if the metadata is ready to use,
  //or false if there was an error during the process.
  static Future<bool> prepareMetadataBuild() async {
    var registryFile =
        File(FileSystemService.metadatasPath + "/${DOWNLOAD_MARK_FILENAME}");
    int? contentLength = null;
    try {
      var res = await Dio().head(AppConstants.libretroMetadatasReleaseBuild);
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
          url: Uri.parse(AppConstants.libretroMetadatasReleaseBuild),
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
            inputFile, Directory(FileSystemService.metadatasPath));
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
    var registryFile =
        File(FileSystemService.metadatasPath + "/libretro-index.json");
    if (!registryFile.existsSync()) {
      throw Exception("Metadata registry file not found.");
    }
    var content = jsonDecode(registryFile.readAsStringSync());
    List<LaunchboxRegistry> registries = [];
    for (final item in content) {
      registries.add(LaunchboxRegistry.fromJson(item));
    }
    return registries;
  }
}
