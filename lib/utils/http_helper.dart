import 'package:http/http.dart' as http;

class HttpHelper {
  // This function sends an HTTP GET request to the specified URI and follows redirects up to a maximum number of times.
  Future<http.StreamedResponse> sendRequestWithRedirects(
    http.Client client,
    Uri uri,
    Map<String, String> headers, {
    int maxRedirects = 5,
  }) async {
    Uri currentUri = uri;

    for (int i = 0; i < maxRedirects; i++) {
      final request = http.Request("GET", currentUri)
        ..headers.addAll(headers)
        ..followRedirects = false;

      final response = await client.send(request);

      if (response.statusCode < 300 || response.statusCode >= 400) {
        return response;
      }

      final location = response.headers['location'];
      if (location == null) {
        return response;
      }

      final nextUri = Uri.parse(location);

      print("Redirect ${i + 1}: $currentUri → $nextUri");

      currentUri =
          nextUri.isAbsolute ? nextUri : currentUri.resolveUri(nextUri);
    }

    throw Exception("Too many redirects");
  }

  Map<String, String> parseHeaders(String raw) {
    final Map<String, String> headers = {};

    if (raw.trim().isEmpty) return headers;

    final parts = raw.split(';');

    for (var part in parts) {
      try {
        final trimmed = part.trim();
        if (trimmed.isEmpty) continue;

        final index = trimmed.indexOf(':');

        if (index <= 0 || index == trimmed.length - 1) continue;

        final key = trimmed.substring(0, index).trim();
        final value = trimmed.substring(index + 1).trim();

        if (key.isEmpty) continue;

        headers[key] = value;
      } catch (_) {
        continue;
      }
    }

    return headers;
  }
}
