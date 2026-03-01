abstract class Hoster {
  bool canHandleUrl(String url);
  String get name;
  Future<String?> extractFileName(String url);
  Future<String?> extractDownloadUrl(String url);
  bool isValidDirectDownloadUrl(String url);
}
