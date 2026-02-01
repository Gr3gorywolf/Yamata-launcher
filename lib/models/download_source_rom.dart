class DownloadSourceRom {
  String? fileSize;
  String? title_clean;
  List<String>? uris;
  String? title;
  String? filePath;
  String? fileName;
  int? fileIndex;
  String? uploadDate;
  String? console;

  DownloadSourceRom(
      {this.fileSize,
      this.uris,
      this.title,
      this.title_clean,
      this.filePath,
      this.fileIndex,
      this.fileName,
      this.uploadDate,
      this.console});

  DownloadSourceRom copyWith({
    String? fileSize,
    String? title_clean,
    List<String>? uris,
    String? title,
    String? filePath,
    String? fileName,
    int? fileIndex,
    String? uploadDate,
    String? console,
  }) {
    return DownloadSourceRom(
        fileSize: fileSize ?? this.fileSize,
        title_clean: title_clean ?? this.title_clean,
        uris:
            uris ?? (this.uris != null ? List<String>.from(this.uris!) : null),
        title: title ?? this.title,
        filePath: filePath ?? this.filePath,
        fileIndex: fileIndex ?? this.fileIndex,
        uploadDate: uploadDate ?? this.uploadDate,
        console: console ?? this.console,
        fileName: fileName ?? this.fileName);
  }

  DownloadSourceRom.fromJson(Map<String, dynamic> json) {
    fileSize = json['fileSize'];
    uris = json['uris'].cast<String>();
    title = json['title'];
    filePath = json['filePath'];
    fileIndex = json['fileIndex'];
    uploadDate = json['uploadDate'];
    console = json['console'];
    title_clean = json['title_clean'] ?? null;
    fileName = json['fileName'] ?? null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['fileSize'] = this.fileSize;
    data['uris'] = this.uris;
    data['title'] = this.title;
    data['filePath'] = this.filePath;
    data['fileIndex'] = this.fileIndex;
    data['uploadDate'] = this.uploadDate;
    data['console'] = this.console;
    data['title_clean'] = this.title_clean;
    data['fileName'] = this.fileName;
    return data;
  }
}
