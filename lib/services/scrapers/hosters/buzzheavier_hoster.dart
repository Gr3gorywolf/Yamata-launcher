import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class BuzzHeavierHoster implements Hoster {
  @override
  String get name => 'BuzzHeavier';

  static const List<String> _buzzheavierDomains = [
    'buzzheavier.com',
    'bzzhr.co',
    'fuckingfast.net',
  ];

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _buzzheavierDomains.any(lower.contains);
  }

  // =========================
  // FILENAME
  // =========================
  @override
  Future<String?> extractFileName(String url) async {
    try {
      final directUrl = await extractDownloadUrl(url);
      return CommonHosterUtils().extractHosterFilename(url, directUrl: url);
    } catch (e) {
      print('[BuzzHeavier] extractFileName failed: $e');
      return null;
    }
  }

  // =========================
  // DIRECT DOWNLOAD URL
  // =========================
  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    final baseUrl = url.split('#').first;
    print('[BuzzHeavier] Starting download link extraction for: $baseUrl');

    try {
      // -------------------------
      // 1. Initial GET (session warmup)
      // -------------------------
      await http.get(
        Uri.parse(baseUrl),
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        },
      ).timeout(const Duration(seconds: 30));

      // -------------------------
      // 2. HEAD /download (NO redirect follow)
      // -------------------------
      final downloadUrl = '$baseUrl/download';
      print('[BuzzHeavier] Making HEAD request to: $downloadUrl');

      final client = http.Client();
      final request = http.Request('HEAD', Uri.parse(downloadUrl))
        ..followRedirects = false
        ..headers.addAll({
          'hx-current-url': baseUrl,
          'hx-request': 'true',
          HttpHeaders.refererHeader: baseUrl,
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        });

      final streamed =
          await client.send(request).timeout(const Duration(seconds: 30));

      final status = streamed.statusCode;
      final headers = streamed.headers;

      print('[BuzzHeavier] HEAD status: $status');

      // Valid statuses like Axios
      if (![200, 204, 301, 302].contains(status)) {
        throw Exception('Unexpected status code: $status');
      }

      final hxRedirect = headers['hx-redirect'];
      print('[BuzzHeavier] Received hx-redirect header: $hxRedirect');

      if (hxRedirect == null || hxRedirect.isEmpty) {
        throw Exception(
          'Could not extract download link. File may be deleted or is a directory.',
        );
      }

      // -------------------------
      // 3. Normalize direct link
      // -------------------------
      final domain = Uri.parse(baseUrl).host;
      final directLink = hxRedirect.startsWith('/dl/')
          ? 'https://$domain$hxRedirect'
          : hxRedirect;

      print('[BuzzHeavier] Extracted direct link');
      client.close();
      return directLink;
    } catch (e) {
      print('[BuzzHeavier] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }
}
