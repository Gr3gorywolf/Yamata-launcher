import 'dart:io';

import 'package:flutter/services.dart';

class AppConstants {
  static String repositoryBasePath = "Gr3gorywolf/Yamata-launcher";
  static String apiBasePath =
      "https://raw.githubusercontent.com/Gr3gorywolf/NeonRom3r-RomsInfos/neo/";
  static String serverBaseUrl = "https://api.yamata-launcher.gregoryc.dev/";
  static String appName = "Yamata Launcher";
  static String baseImagesPath = "assets/images";
  static String appGuid = 'e5a55a91-bdd4-4536-99be-05a564ae1882';

  static String discordLink = "https://discord.gg/4TegCDgQkx";
  static String guideLink =
      "https://github.com/Gr3gorywolf/Yamata-launcher/wiki";

  static String libretroMetadatasSite =
      "https://gr3gorywolf.github.io/libretro-metadatas";

  static String libretroMetadatasReleaseBuild =
      "https://github.com/Gr3gorywolf/libretro-metadatas/releases/latest/download/build.zip";

  static String gameRunnersGuideEntry =
      "https://github.com/Gr3gorywolf/Yamata-launcher/wiki/Game-runners";

  static String cookiesGuideEntry =
      "https://github.com/Gr3gorywolf/Yamata-launcher/wiki/How-to-Extract-Cookies-from-Your-Browser";

  static String manualExtractionGuideEntry =
      "https://github.com/Gr3gorywolf/Yamata-launcher/wiki/Manual-interaction-on-download-sources";

  static String externalLinkExtractorLink =
      "https://github.com/Gr3gorywolf/yamata-launcher-link-extractor/releases/latest/download/yamata-link-extractor-${Platform.isWindows ? "windows" : Platform.isLinux ? "linux" : "macos"}.zip";
}
