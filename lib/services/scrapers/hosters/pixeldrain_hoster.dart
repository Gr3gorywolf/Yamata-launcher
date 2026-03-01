import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/exceptions/download_require_manual_exception.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class PixelDrainHoster implements Hoster {
  @override
  String get name => 'PixelDrain';

  static const _domains = [
    'pixeldrain.com',
    'pd.cybar.xyz',
  ];

  static const _browserHeaders = {
    HttpHeaders.userAgentHeader:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    HttpHeaders.acceptHeader:
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Connection': 'keep-alive',
  };

  @override
  bool canHandleUrl(String url) {
    return _domains.any((d) => url.toLowerCase().contains(d));
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    return url.contains("api/file");
  }

  // =========================
  // PUBLIC
  // =========================

  @override
  Future<String?> extractFileName(String url) async {
    try {
      final directUrl = await extractDownloadUrl(url);
      return CommonHosterUtils()
          .extractHosterFilename(url, directUrl: directUrl);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    try {
      final fileId = _extractFileId(url);
      if (fileId == null) {
        throw Exception('Invalid PixelDrain URL');
      }

      final mirrorUrl = 'https://pd.cybar.xyz/$fileId';

      final client = http.Client();

      final request = http.Request('GET', Uri.parse(mirrorUrl))
        ..headers.addAll(_browserHeaders)
        ..followRedirects = false;

      final response =
          await client.send(request).timeout(const Duration(seconds: 30));

      // Redirect expected
      if (response.isRedirect ||
          response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 200) {
        final location = response.headers[HttpHeaders.locationHeader];

        if (location == null || location.isEmpty) {
          throw DownloadRequireManualException(
              'PixelDrain: No redirect URL found');
        }

        return '$location||headers:User-Agent:${CommonHosterUtils().hosterUserAgent}';
      }

      throw Exception('PixelDrain: Unexpected status ${response.statusCode}');
    } catch (e) {
      print('[PixelDrain] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  String? _extractFileId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;

      // pixeldrain.com/u/<id>
      if (segments.length >= 2 && segments[0] == 'u') {
        return segments[1];
      }

      // pixeldrain.com/<id>
      if (segments.isNotEmpty) {
        return segments.last;
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
