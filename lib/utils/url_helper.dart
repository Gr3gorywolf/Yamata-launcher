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

  static String getUrlWithoutHeaders(String url) {
    if (!url.contains("||headers:")) return url;
    return url.split("||headers:").first;
  }

  static String appendHeadersToUrl(String url, Map<String, String> headers) {
    var headersString = headers.entries
        .map((entry) =>
            "${entry.key}:${entry.value.trim().replaceAll("\n", "")}")
        .join("^");
    return "$url||headers:$headersString";
  }

  static Map<String, String> extractHeadersFromUrl(String url) {
    if (!url.contains("||headers:")) return {};
    var fragment = url.split("||headers:")[1];
    final headers = <String, String>{};
    for (var header in fragment.split("^")) {
      var parts = header.split(":");
      if (parts.length >= 2) {
        var key = parts[0].trim();
        var value = parts.sublist(1).join(":").trim();
        headers[key] = value;
      }
    }
    return headers;
  }
}
