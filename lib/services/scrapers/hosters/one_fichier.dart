import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class OneFichierHoster implements Hoster {
  @override
  String get name => '1Fichier';

  static const List<String> _domains = [
    '1fichier.com',
  ];

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _domains.any(lower.contains);
  }

  @override
  Future<String?> extractFileName(String url) async {
    try {
      final directUrl = await extractDownloadUrl(url);
      return CommonHosterUtils().extractHosterFilename(
        url,
        directUrl: directUrl,
      );
    } catch (e) {
      print('[1Fichier] extractFileName failed: $e');
      return null;
    }
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    try {
      final normalized = _normalizeUrl(url);

      final response = await http.get(
        Uri.parse(normalized),
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
          HttpHeaders.acceptHeader: 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode >= 400) {
        throw Exception('1Fichier page returned ${response.statusCode}');
      }

      final html = response.body;
      _throwIfBlockedOrWaiting(html);

      final directUrl = _extractDirectUrlFromHtml(html, normalized);
      if (directUrl == null) {
        throw Exception('Could not extract direct download link from 1Fichier');
      }

      await _checkDownloadUrl(directUrl, referer: normalized);

      // Keep compatibility with hosters that pass headers in the URL suffix.
      return '$directUrl||headers:Referer: $normalized';
    } catch (e) {
      print('[1Fichier] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  String _normalizeUrl(String url) {
    final uri = Uri.parse(url.trim());
    return uri.removeFragment().toString();
  }

  void _throwIfBlockedOrWaiting(String html) {
    final lower = html.toLowerCase();

    // 1Fichier often requires waiting/captcha for free mode.
    if (lower.contains('you must wait') ||
        lower.contains('must wait') ||
        lower.contains('please wait') ||
        lower.contains('captcha') ||
        lower.contains('wrong password')) {
      throw Exception(
        '1Fichier requires wait/captcha/password for this file in free mode',
      );
    }
  }

  String? _extractDirectUrlFromHtml(String html, String baseUrl) {
    // Typical "Click here to download the file"
    final anchorRegex = RegExp(
      r'href\s*=\s*"([^"]+)"[^>]*>\s*(?:click here to download|download)',
      caseSensitive: false,
      dotAll: true,
    );
    final anchorMatch = anchorRegex.firstMatch(html);
    if (anchorMatch != null) {
      return _toAbsolute(anchorMatch.group(1)!, baseUrl);
    }

    // Some pages expose the action URL in the download form.
    final formRegex = RegExp(
      r'<form[^>]+action\s*=\s*"([^"]+)"[^>]*id\s*=\s*"[^"]*dl[^"]*"',
      caseSensitive: false,
      dotAll: true,
    );
    final formMatch = formRegex.firstMatch(html);
    if (formMatch != null) {
      return _toAbsolute(formMatch.group(1)!, baseUrl);
    }

    // JS redirect fallback.
    final jsRegex = RegExp(
      r'''location\.href\s*=\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    );
    final jsMatch = jsRegex.firstMatch(html);
    if (jsMatch != null) {
      return _toAbsolute(jsMatch.group(1)!, baseUrl);
    }

    return null;
  }

  String _toAbsolute(String maybeRelative, String baseUrl) {
    final trimmed = maybeRelative.trim();
    final uri = Uri.parse(trimmed);

    if (uri.hasScheme) return trimmed;
    return Uri.parse(baseUrl).resolveUri(uri).toString();
  }

  Future<void> _checkDownloadUrl(String url, {required String referer}) async {
    final response = await http.head(
      Uri.parse(url),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.refererHeader: referer,
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Direct url check failed: ${response.statusCode}');
    }
  }
}
