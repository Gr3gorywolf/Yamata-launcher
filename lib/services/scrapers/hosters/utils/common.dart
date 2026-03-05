import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

class CommonHosterUtils {
  static Map<String, String> directDownloadUris = {};
  String hosterUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0 Safari/537.36";

  Future<String> extractHosterFilename(
    String rawUrl, {
    String? directUrl,
  }) async {
    var url = rawUrl.trim();
    if (url.contains("||")) {
      url = url.split("||").first;
    }
    // =========================
    // 1. Fragment (#filename)
    // =========================
    if (url.contains('#')) {
      final fragment = url.split('#').last;
      if (fragment.isNotEmpty && !fragment.startsWith('http')) {
        return fragment;
      }
    }

    // =========================
    // 2. HEAD request
    // =========================
    if (directUrl != null) {
      try {
        final uri = Uri.parse(directUrl);

        final response = await http.head(
          uri,
          headers: {
            HttpHeaders.userAgentHeader: hosterUserAgent,
          },
        ).timeout(const Duration(seconds: 10));

        final contentDisposition = response.headers['content-disposition'];

        if (contentDisposition != null) {
          final regex = RegExp(r'filename\s*=\s*"?([^";\n]+)"?');
          final match = regex.firstMatch(contentDisposition);

          if (match != null) {
            return match.group(1)!;
          }
        }
      } catch (_) {
        // Ignore errors (same behavior as TS)
      }

      // =========================
      // 3. Fallback to URL path
      // =========================
      try {
        final uri = Uri.parse(directUrl);
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          return segments.last;
        }
      } catch (_) {}
    }

    // =========================
    // 4. Default fallback
    // =========================
    return 'downloaded_file';
  }

  Future<Document?> fetchHtml(String url) async {
    try {
      final headers = {
        "User-Agent": "curl/8.0.1",
        HttpHeaders.acceptHeader: '*/*',
        "Referer": url,
        "Connection": "keep-alive",
      };

      final dio = Dio(
        BaseOptions(
          followRedirects: true,
          maxRedirects: 10,
          validateStatus: (s) => true,
          headers: headers,
        ),
      );

      final res = await dio.get(
        url,
      );

      if (res == null) {
        return null;
      }
      if ((res?.statusCode ?? 404) >= 400) {
        return null;
      }
      return parser.parse(res.data.toString());
    } catch (err) {
      print('[CommonHosterUtils] fetchHtml error: $err');
      return null;
    }
  }

  Never handleHosterError(Object error, [http.Response? response]) {
    if (response != null) {
      switch (response.statusCode) {
        case 404:
          throw Exception('File not found');
        case 429:
          throw Exception('Rate limit exceeded. Please try again later.');
        case 403:
          throw Exception('Access denied. File may be private or deleted.');
        default:
          throw Exception(
            'Network error: ${response.statusCode}',
          );
      }
    }

    if (error is TimeoutException) {
      throw Exception('Network timeout');
    }

    if (error is SocketException) {
      throw Exception('No internet connection');
    }

    throw error;
  }
}
