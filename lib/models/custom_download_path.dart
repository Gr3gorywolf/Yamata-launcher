class CustomDownloadPath {
  String folderPath = "";
  String console = "";

  CustomDownloadPath({required this.folderPath, required this.console});

  CustomDownloadPath.fromJson(Map<String, dynamic> json) {
    folderPath = json['folderPath'] ?? '';
    console = json['console'] ?? '';
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['folderPath'] = this.folderPath;
    data['console'] = this.console;
    return data;
  }
}
