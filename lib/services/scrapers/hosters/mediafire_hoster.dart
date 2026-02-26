import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class MediafireHoster implements Hoster {
  @override
  String get name => 'Mediafire';

  static const List<String> _domains = [
    'mediafire.com',
    'mfi.re',
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
      print('[Mediafire] extractFileName failed: $e');
      return null;
    }
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    final client = http.Client();
    try {
      final normalized = _normalizeUrl(url);
      final html = await _getHtml(client, normalized);

      _throwIfOffline(html);
      _throwIfBlocked(html);

      // Priority 1: scrambled base64 url (same behavior as pyLoad plugin).
      final scrambled = _extractScrambledUrl(html);
      if (scrambled != null) {
        await _checkDownloadUrl(client, scrambled, referer: normalized);
        return scrambled;
      }

      // Priority 2: "Download file" anchor.
      final href = _extractDownloadHref(html, normalized);
      if (href != null) {
        await _checkDownloadUrl(client, href, referer: normalized);
        return href;
      }

      throw Exception('Could not extract Mediafire direct link');
    } catch (e) {
      print('[Mediafire] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    } finally {
      client.close();
    }
  }

  String _normalizeUrl(String url) {
    return Uri.parse(url.trim()).removeFragment().toString();
  }

  Future<String> _getHtml(http.Client client, String url) async {
    final response = await client.get(
      Uri.parse(url),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.acceptHeader: 'text/html,application/xhtml+xml,*/*',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Mediafire page returned ${response.statusCode}');
    }

    return response.body;
  }

  void _throwIfOffline(String html) {
    final lower = html.toLowerCase();
    if (lower.contains('class="error_msg_title"') ||
        lower.contains('file removed') ||
        lower.contains('file invalid or deleted')) {
      throw Exception('Mediafire file is offline');
    }
  }

  void _throwIfBlocked(String html) {
    final lower = html.toLowerCase();
    if (lower.contains('name="form_password"')) {
      throw Exception('Mediafire link is password-protected');
    }
    if (lower.contains('g-recaptcha') ||
        lower.contains('solvemedia') ||
        lower.contains('form_captcha')) {
      throw Exception('Mediafire requires captcha');
    }
  }

  String? _extractScrambledUrl(String html) {
    final match = RegExp(
      r'''data-scrambled-url="([^"]+)"''',
      caseSensitive: false,
    ).firstMatch(html);

    if (match == null) return null;

    try {
      final encoded = match.group(1)!;
      final bytes = base64Decode(encoded);
      final decoded = utf8.decode(bytes, allowMalformed: true).trim();
      if (decoded.startsWith('http://') || decoded.startsWith('https://')) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _extractDownloadHref(String html, String baseUrl) {
    final match = RegExp(
      r'''aria-label="Download file"\s+href="([^"]+)"''',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    if (match == null) return null;
    return _toAbsolute(match.group(1)!, baseUrl);
  }

  String _toAbsolute(String maybeRelative, String baseUrl) {
    final value = maybeRelative.trim();
    final uri = Uri.parse(value);
    if (uri.hasScheme) return value;
    return Uri.parse(baseUrl).resolveUri(uri).toString();
  }

  Future<void> _checkDownloadUrl(
    http.Client client,
    String url, {
    required String referer,
  }) async {
    final headReq = http.Request('HEAD', Uri.parse(url))
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers.addAll({
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.refererHeader: referer,
      });

    final head =
        await client.send(headReq).timeout(const Duration(seconds: 30));

    if (head.statusCode == 405) {
      final probe = await client.get(
        Uri.parse(url),
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
          HttpHeaders.refererHeader: referer,
          HttpHeaders.rangeHeader: 'bytes=0-0',
        },
      ).timeout(const Duration(seconds: 30));

      if (probe.statusCode >= 400) {
        throw Exception('Direct url probe failed: ${probe.statusCode}');
      }
      return;
    }

    if (head.statusCode >= 400) {
      throw Exception('Direct url check failed: ${head.statusCode}');
    }
  }
}
