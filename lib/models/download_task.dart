import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';

class DownloadTask {
  final String slug;
  final DownloadSourceRom sourceRom;
  final DownloadInfo download;

  DownloadTask({
    required this.slug,
    required this.sourceRom,
    required this.download,
  });

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      slug: json['slug'] as String,
      sourceRom: DownloadSourceRom.fromJson(
        json['sourceRom'] as Map<String, dynamic>,
      ),
      download: DownloadInfo.fromJson(
        json['download'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'sourceRom': sourceRom.toJson(),
      'download': download.toJson(),
    };
  }
}
