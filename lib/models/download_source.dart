import 'download_source_rom.dart';

class DownloadSource {
  String title = "Unknown";
  List<String>? passwords = [];
  String? downloadUrl;
  int? romsCount;
  String? lastUpdated;

  DownloadSource(
      {required this.title,
      this.passwords,
      this.romsCount,
      this.lastUpdated,
      this.downloadUrl});
  DownloadSource.fromJson(Map<String, dynamic> json) {
    title = json['title'] ?? "";
    romsCount = json['roms_count'];
    lastUpdated = json['last_updated'];
    downloadUrl = json['download_url'];
    if (json['passwords'] != null) {
      passwords = List<String>.from(json['passwords']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['title'] = this.title;
    data['roms_count'] = this.romsCount;
    data['last_updated'] = this.lastUpdated;
    data['download_url'] = this.downloadUrl;
    if (this.passwords != null) {
      data['passwords'] = this.passwords;
    }
    return data;
  }
}

class DownloadSourceWithDownloads {
  DownloadSource sourceInfo =
      DownloadSource(title: "Unknown", romsCount: 0, lastUpdated: null);
  List<DownloadSourceRom> downloads = [];

  DownloadSourceWithDownloads(
      {required this.sourceInfo, required this.downloads});

  DownloadSourceWithDownloads.fromJson(Map<String, dynamic> json) {
    sourceInfo = DownloadSource.fromJson(json['sourceInfo']);
    if (json['downloads'] != null) {
      downloads = [];
      json['downloads'].forEach((v) {
        downloads.add(new DownloadSourceRom.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.sourceInfo != null) {
      data['sourceInfo'] = this.sourceInfo!.toJson();
    }
    if (this.downloads != null) {
      data['downloads'] = this.downloads!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}
