import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class DatanodesHoster implements Hoster {
  @override
  String get name => 'Datanodes';
  static const List<String> _datanodesDomains = [
    'datanodes.to',
  ];

  final Map<String, String> _cookies = {};

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _datanodesDomains.any(lower.contains);
  }

  // =========================
  // FILENAME
  // =========================
  @override
  Future<String?> extractFileName(String url) async {
    try {
      final directUrl = await extractDownloadUrl(url);
      return CommonHosterUtils()
          .extractHosterFilename(url, directUrl: directUrl);
    } catch (e) {
      print('[Datanodes] extractFileName failed: $e');
      return null;
    }
  }

  // =========================
  // DIRECT DOWNLOAD URL
  // =========================
  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) {
      return null;
    }

    print('[Datanodes] Starting download link extraction for: $url');

    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

      if (segments.isEmpty) {
        throw Exception('Invalid datanodes url');
      }

      // TS: const fileCode = pathSegments[0];
      final fileCode = segments.first;

      // -------------------------
      // 1. Set cookie: lang=english
      // -------------------------
      _cookies['lang'] = 'english';

      // -------------------------
      // 2. Build form data
      // -------------------------
      final formData = {
        'op': 'download2',
        'id': fileCode,
        'rand': '',
        'referer': 'https://datanodes.to/download',
        'method_free': 'Free Download >>',
        'method_premium': '',
        '__dl': '1',
      };

      // -------------------------
      // 3. POST /download
      // -------------------------
      final response = await http
          .post(
            Uri.parse('https://datanodes.to/download'),
            headers: {
              HttpHeaders.acceptHeader: '*/*',
              HttpHeaders.acceptLanguageHeader: 'en-US,en;q=0.9',
              HttpHeaders.refererHeader: 'https://datanodes.to/download',
              HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
              HttpHeaders.cookieHeader: _buildCookieHeader(),
            },
            body: formData,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(
          'Unexpected status code: ${response.statusCode}',
        );
      }

      // -------------------------
      // 4. Parse JSON response
      // -------------------------
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded['url'] is String) {
        final directUrl = Uri.decodeComponent(decoded['url'] as String);

        print('[Datanodes] Extracted direct link');
        return directUrl;
      }

      throw Exception('Failed to get the download link');
    } catch (e) {
      print('[Datanodes] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
    }
  }

  // =========================
  // COOKIE HELPERS
  // =========================
  String _buildCookieHeader() {
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
}
