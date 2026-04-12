abstract class Debrider {
  String get name;
  String get settingKey;
  Future<bool> isAuthenticated();
  bool canHandleUrl(String url);
  Future<String> getDirectDownloadLink(String magnetUrl);
}
