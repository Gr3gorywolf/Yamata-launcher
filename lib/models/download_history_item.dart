import 'package:yamata_launcher/models/contracts/json_serializable.dart';
import 'package:yamata_launcher/models/download_info.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';

class DownloadHistoryItem implements JsonSerializable {
  String romSlug;
  DateTime? downloadedAt;
  RomInfo? romInfo;
  String? contentTitle;
  String? filePath;
  String? downloadId;
  bool isExtraContent;

  DownloadHistoryItem({
    required this.romSlug,
    this.romInfo,
    this.contentTitle,
    this.isExtraContent = false,
    this.downloadedAt,
    this.filePath,
    this.downloadId,
  });

  factory DownloadHistoryItem.fromDownloadInfo(DownloadInfo info,
      {String? filePath, DateTime? downloadedAt}) {
    return DownloadHistoryItem(
      romSlug: info.romSlug,
      romInfo: info.romInfo,
      contentTitle: info.contentTitle,
      isExtraContent: info.isExtraContent,
      downloadedAt: downloadedAt ?? DateTime.now(),
      filePath: filePath,
      downloadId: info.downloadId,
    );
  }

  factory DownloadHistoryItem.fromJson(Map<String, dynamic> json) {
    return DownloadHistoryItem(
      romSlug: json['romSlug'] as String,
      contentTitle: json['contentTitle'] as String?,
      filePath: json['filePath'] as String?,
      isExtraContent: json['isExtraContent'] as bool? ?? false,
      downloadId: json['downloadId'] as String?,
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.tryParse(json['downloadedAt'])
          : null,
      romInfo: json['romInfo'] != null
          ? RomInfo.fromJson(
              Map<String, dynamic>.from(json['romInfo']),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'romSlug': romSlug,
      'contentTitle': contentTitle,
      'filePath': filePath,
      'isExtraContent': isExtraContent,
      'downloadedAt': downloadedAt?.toIso8601String(),
      'downloadId': downloadId,
      'romInfo': romInfo?.toJson(),
    };
  }
}
