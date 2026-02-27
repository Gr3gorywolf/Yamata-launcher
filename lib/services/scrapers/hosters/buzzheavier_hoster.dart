import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class BuzzHeavierHoster implements Hoster {
  @override
  String get name => 'BuzzHeavier';

  static const _domains = [
    'buzzheavier.com',
    'bzzhr.co',
    'fuckingfast.net',
  ];

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _domains.any(lower.contains);
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
      final baseUrl = _cleanUrl(url);
      final uri = Uri.parse(baseUrl);

      final headers = {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      };

      // 1️⃣ Initial GET (required)
      await http
          .get(
            uri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      // 2️⃣ HEAD to /download
      final downloadUrl = '$baseUrl/download';

      final request = http.Request('HEAD', Uri.parse(downloadUrl))
        ..followRedirects = false
        ..headers.addAll({
          'hx-current-url': baseUrl,
          'hx-request': 'true',
          HttpHeaders.refererHeader: baseUrl,
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        });

      final response =
          await request.send().timeout(const Duration(seconds: 30));

      final hxRedirect = response.headers['hx-redirect'];

      if (hxRedirect == null || hxRedirect.isEmpty) {
        throw Exception('Buzzheavier: hx-redirect not found');
      }

      // 3️⃣ Build final link
      final directLink = hxRedirect.startsWith('/dl/')
          ? 'https://${uri.host}$hxRedirect'
          : hxRedirect;

      return '$directLink||headers:Referer: $baseUrl^User-Agent: ${CommonHosterUtils().hosterUserAgent}';
    } catch (e) {
      print('[Buzzheavier] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  String _cleanUrl(String url) {
    // Remove fragment (#...)
    final index = url.indexOf('#');
    return index != -1 ? url.substring(0, index) : url;
  }
}
