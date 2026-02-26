import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class GoogleDriveHoster implements Hoster {
  @override
  String get name => 'GoogleDrive';

  static const List<String> _domains = [
    'drive.google.com',
    'docs.google.com',
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
      return CommonHosterUtils()
          .extractHosterFilename(url, directUrl: directUrl);
    } catch (e) {
      print('[GoogleDrive] extractFileName failed: $e');
      return null;
    }
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    final client = http.Client();
    try {
      final fileId = _extractFileId(url);
      if (fileId == null || fileId.isEmpty) {
        throw Exception('Could not extract Google Drive file id');
      }

      final initial = Uri.https('drive.google.com', '/uc', {
        'export': 'download',
        'id': fileId,
      });

      final first = await _getNoRedirect(client, initial);
      final firstRedirect = _redirectFrom(first, initial);
      if (firstRedirect != null) {
        await _checkDownloadUrl(client, firstRedirect);
        return firstRedirect.toString();
      }

      final html = await first.stream.bytesToString();

      final confirmUrl = _extractConfirmUrl(html, fileId);
      if (confirmUrl == null) {
        throw Exception('Could not extract Google Drive confirmation url');
      }

      final cookieHeader = _extractCookieHeader(first.headers['set-cookie']);
      final second = await _getNoRedirect(
        client,
        confirmUrl,
        headers: cookieHeader == null
            ? null
            : {HttpHeaders.cookieHeader: cookieHeader},
      );

      final finalRedirect = _redirectFrom(second, confirmUrl);
      if (finalRedirect == null) {
        throw Exception('Google Drive direct link redirect not found');
      }

      await _checkDownloadUrl(client, finalRedirect);

      if (cookieHeader != null && cookieHeader.isNotEmpty) {
        return '${finalRedirect.toString()}||headers:Cookie: $cookieHeader';
      }
      return finalRedirect.toString();
    } catch (e) {
      print('[GoogleDrive] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    } finally {
      client.close();
    }
  }

  String? _extractFileId(String url) {
    final uri = Uri.parse(url.trim());
    final segments = uri.pathSegments;

    // /file/d/<id>/view
    final dIndex = segments.indexOf('d');
    if (dIndex >= 0 && dIndex + 1 < segments.length) {
      return segments[dIndex + 1];
    }

    // /uc?id=<id> or /open?id=<id>
    final queryId = uri.queryParameters['id'];
    if (queryId != null && queryId.isNotEmpty) {
      return queryId;
    }

    // Fallback
    final match = RegExp(r'[-\w]{20,}').firstMatch(url);
    return match?.group(0);
  }

  Future<http.StreamedResponse> _getNoRedirect(
    http.Client client,
    Uri uri, {
    Map<String, String>? headers,
  }) {
    final req = http.Request('GET', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers.addAll({
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.acceptHeader: 'text/html,application/xhtml+xml,*/*',
        if (headers != null) ...headers,
      });

    return client.send(req).timeout(const Duration(seconds: 30));
  }

  Uri? _redirectFrom(http.StreamedResponse response, Uri base) {
    if (response.statusCode < 300 || response.statusCode >= 400) return null;
    final location = response.headers[HttpHeaders.locationHeader];
    if (location == null || location.isEmpty) return null;
    return base.resolve(location);
  }

  Uri? _extractConfirmUrl(String html, String fileId) {
    // Typical warning page link: /uc?export=download&confirm=...&id=...
    final href = RegExp(
      r'href="([^"]*?/uc\?export=download[^"]+)"',
      caseSensitive: false,
    ).firstMatch(html);

    if (href != null) {
      final raw = href.group(1)!.replaceAll('&amp;', '&');
      return Uri.parse('https://drive.google.com').resolve(raw);
    }

    final confirm =
        RegExp(r'confirm=([0-9A-Za-z_-]+)').firstMatch(html)?.group(1);
    if (confirm != null) {
      return Uri.https('drive.google.com', '/uc', {
        'export': 'download',
        'confirm': confirm,
        'id': fileId,
      });
    }

    return null;
  }

  String? _extractCookieHeader(String? setCookie) {
    if (setCookie == null || setCookie.isEmpty) return null;

    // Keeps only name=value pairs (good enough for download_warning cookie usage).
    final pairs = <String>[];
    for (final part in setCookie.split(',')) {
      final first = part.trim().split(';').first.trim();
      if (first.contains('=')) pairs.add(first);
    }

    if (pairs.isEmpty) return null;
    return pairs.join('; ');
  }

  Future<void> _checkDownloadUrl(http.Client client, Uri url) async {
    final headReq = http.Request('HEAD', url)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers[HttpHeaders.userAgentHeader] =
          CommonHosterUtils().hosterUserAgent;

    final head =
        await client.send(headReq).timeout(const Duration(seconds: 30));

    if (head.statusCode == 405) {
      final probeReq = http.Request('GET', url)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers[HttpHeaders.userAgentHeader] =
            CommonHosterUtils().hosterUserAgent
        ..headers[HttpHeaders.rangeHeader] = 'bytes=0-0';
      final probe =
          await client.send(probeReq).timeout(const Duration(seconds: 30));
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
