class DownloadSourceRom {
  String? fileSize;
  String? titleClean;
  List<String>? uris;
  String? title;
  String? filePath;
  String? fileName;
  int? fileIndex;
  String? uploadDate;
  String? console;
  bool? isExtraContent;

  DownloadSourceRom(
      {this.fileSize,
      this.uris,
      this.title,
      this.titleClean,
      this.filePath,
      this.fileIndex,
      this.fileName,
      this.uploadDate,
      this.isExtraContent,
      this.console});

  DownloadSourceRom copyWith({
    String? fileSize,
    String? titleClean,
    List<String>? uris,
    String? title,
    String? filePath,
    String? fileName,
    int? fileIndex,
    String? uploadDate,
    String? console,
    bool? isExtraContent,
  }) {
    return DownloadSourceRom(
        fileSize: fileSize ?? this.fileSize,
        titleClean: titleClean ?? this.titleClean,
        uris:
            uris ?? (this.uris != null ? List<String>.from(this.uris!) : null),
        title: title ?? this.title,
        filePath: filePath ?? this.filePath,
        fileIndex: fileIndex ?? this.fileIndex,
        uploadDate: uploadDate ?? this.uploadDate,
        console: console ?? this.console,
        isExtraContent: isExtraContent ?? this.isExtraContent,
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
    titleClean = json['titleClean'] ?? null;
    fileName = json['fileName'] ?? null;
    isExtraContent = json['isExtraContent'] ?? false;
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
    data['titleClean'] = this.titleClean;
    data['fileName'] = this.fileName;
    data['isExtraContent'] = this.isExtraContent;
    return data;
  }
}
