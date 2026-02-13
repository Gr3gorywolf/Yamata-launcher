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
  bool get isCompleted {
    return downloadPercent == 100;
  }

  DownloadInfo(
      {required this.romSlug,
      this.downloadPercent,
      this.downloadId,
      this.romInfo,
      this.downloadFolder,
      this.contentTitle,
      this.shouldExtract,
      this.isExtraContent = false,
      this.isExtracting = false,
      this.totalSize,
      this.downloadInfo});
}
