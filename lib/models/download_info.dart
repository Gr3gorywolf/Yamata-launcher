import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/models/rom_library_item.dart';

class DownloadInfo {
  String romSlug;
  int? downloadPercent;
  String? downloadFolder;
  String? downloadId;
  String? downloadInfo;
  bool isExtracting;
  RomInfo? romInfo;
  String? contentTitle;
  bool isExtraContent;
  bool? shouldExtract;
  String? totalSize;
  bool? isPaused;
  String? downloadUrl;
  String? sourceExtractableUrl;

  bool get isCompleted {
    return downloadPercent == 100;
  }

  DownloadInfo({
    required this.romSlug,
    this.downloadPercent,
    this.downloadId,
    this.romInfo,
    this.downloadFolder,
    this.contentTitle,
    this.shouldExtract,
    this.isExtraContent = false,
    this.isExtracting = false,
    this.totalSize,
    this.downloadInfo,
    this.isPaused,
    this.downloadUrl,
    this.sourceExtractableUrl,
  });

  /// From JSON
  factory DownloadInfo.fromJson(Map<String, dynamic> json) {
    return DownloadInfo(
      romSlug: json['romSlug'] as String,
      downloadPercent: json['downloadPercent'] as int?,
      downloadFolder: json['downloadFolder'] as String?,
      downloadId: json['downloadId'] as String?,
      downloadInfo: json['downloadInfo'] as String?,
      isExtracting: json['isExtracting'] as bool? ?? false,
      romInfo:
          json['romInfo'] != null ? RomInfo.fromJson(json['romInfo']) : null,
      contentTitle: json['contentTitle'] as String?,
      isExtraContent: json['isExtraContent'] as bool? ?? false,
      shouldExtract: json['shouldExtract'] as bool?,
      totalSize: json['totalSize'] as String?,
      isPaused: json['isPaused'] as bool?,
      downloadUrl: json['downloadUrl'] as String?,
      sourceExtractableUrl: json['sourceExtractableUrl'] as String?,
    );
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      'romSlug': romSlug,
      'downloadPercent': downloadPercent,
      'downloadFolder': downloadFolder,
      'downloadId': downloadId,
      'downloadInfo': downloadInfo,
      'isExtracting': isExtracting,
      'romInfo': romInfo?.toJson(),
      'contentTitle': contentTitle,
      'isExtraContent': isExtraContent,
      'shouldExtract': shouldExtract,
      'totalSize': totalSize,
      'isPaused': isPaused,
      'downloadUrl': downloadUrl,
      'sourceExtractableUrl': sourceExtractableUrl,
    };
  }
}
