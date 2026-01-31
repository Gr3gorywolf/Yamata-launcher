abstract class Hoster {
  bool canHandleUrl(String url);
  Future<String?> extractFileName(String url);
  Future<String?> extractDownloadUrl(String url);
}
