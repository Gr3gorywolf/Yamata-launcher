import 'package:yamata_launcher/models/rom_info.dart';

import 'console.dart';

class PlatformCatalogSource {
  Console console = Console();
  String? sourceName = "Unknown Source";
  String? downloadUrl;
  List<RomInfo> games = [];

  PlatformCatalogSource(
      {required this.console, required this.sourceName, required this.games});

  PlatformCatalogSource.fromJson(Map<String, dynamic> json) {
    var consoleData = json['console'];
    console = Console(
        fromExternalSource: true,
        name: consoleData['name'],
        slug: consoleData['slug'],
        altName: consoleData['name'],
        logoUrl: consoleData['logoUrl'],
        description: consoleData['description']);
    downloadUrl = json['downloadUrl'];
    games = json['games'] != null
        ? (json['games'] as List).map((i) => RomInfo.fromJson(i)).toList()
        : [];
    sourceName = json['sourceName'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['console'] = {
      "name": this.console.name,
      "slug": this.console.slug,
      "logoUrl": this.console.logoUrl,
      "description": this.console.description,
    };
    data['downloadUrl'] = this.downloadUrl;
    data['games'] = this.games.map((v) => v.toJson()).toList();
    data['sourceName'] = this.sourceName;
    return data;
  }
}
