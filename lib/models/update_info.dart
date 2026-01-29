class UpdateInfo {
  String version = "";
  String changelog = "";
  String fileToDownload = "";
  String? downloadedFilePath;
  int? progress;
  bool? canDismiss;

  bool get isDownloading {
    return progress != null && progress! < 100;
  }

  UpdateInfo(
      {required this.version,
      required this.changelog,
      required this.fileToDownload,
      this.downloadedFilePath,
      this.progress,
      this.canDismiss});
}
