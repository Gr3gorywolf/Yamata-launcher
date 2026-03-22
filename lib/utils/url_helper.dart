class UrlHelper {
  /**
   * Extracts the site from a given URL. For example, if the URL is "https://www.example.com/path", it will return "https://www.example.com".
   */
  static String getSiteFromUrl(String url) {
    try {
      var uri = Uri.parse(url);
      return uri.scheme + "://" + uri.host;
    } catch (e) {
      print(e);
      return url;
    }
  }

  static String appendHeadersToUrl(String url, Map<String, String> headers) {
    var headersString = headers.entries
        .map((entry) =>
            "${entry.key}:${entry.value.trim().replaceAll("\n", "")}")
        .join("^");
    return "$url||headers:$headersString";
  }
}
