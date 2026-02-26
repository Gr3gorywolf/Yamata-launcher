import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class MegaupNetHoster implements Hoster {
  @override
  String get name => 'MegaupNet';

  static const List<String> _domains = [
    'megaup.net',
    'download.megaup.net',
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
      print('[MegaupNet] extractFileName failed: $e');
      return null;
    }
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    try {
      final normalized = _normalizeUrl(url);

      final page = await _getHtml(normalized);

      _throwIfOffline(page);
      _throwIfWaiting(page);

      var direct = _extractDirectLink(page, baseUrl: normalized);
      if (direct != null) {
        await _checkDownloadUrl(direct, referer: normalized);
        return direct;
      }

      // Fallback flow similar to pyLoad plugin:
      // get params -> call https://download.megaup.net/ -> extract redirect
      final params = _extractDownloadParams(page);
      if (params != null) {
        final fallbackHtml = await _callDownloadEndpoint(params);
        direct = _extractDirectLink(
          fallbackHtml,
          baseUrl: 'https://download.megaup.net/',
        );
        if (direct != null) {
          await _checkDownloadUrl(direct, referer: normalized);
          return direct;
        }
      }

      throw Exception('Could not extract Megaup direct link');
    } catch (e) {
      print('[MegaupNet] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  String _normalizeUrl(String url) {
    return Uri.parse(url.trim()).removeFragment().toString();
  }

  Future<String> _getHtml(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.acceptHeader: 'text/html,application/xhtml+xml',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Megaup page returned ${response.statusCode}');
    }

    return response.body;
  }

  void _throwIfOffline(String html) {
    final lower = html.toLowerCase();
    if (lower.contains('no longer available')) {
      throw Exception('Megaup file is offline');
    }
  }

  void _throwIfWaiting(String html) {
    final waitMatch =
        RegExp(r'var\s+seconds\s*=\s*(\d+)\s*;', caseSensitive: false)
            .firstMatch(html);
    if (waitMatch != null) {
      final seconds = int.tryParse(waitMatch.group(1) ?? '');
      if (seconds != null && seconds > 0) {
        throw Exception('Megaup requires waiting time: $seconds seconds');
      }
    }
  }

  String? _extractDirectLink(String html, {required String baseUrl}) {
    // pyLoad pattern: window.location.replace("...")
    final jsRedirect = RegExp(
      r'window\.location\.replace\("([^"]+)"\)',
      caseSensitive: false,
    ).firstMatch(html);
    if (jsRedirect != null) {
      return _toAbsolute(jsRedirect.group(1)!, baseUrl);
    }

    // Generic JS redirect fallback
    final locationHref = RegExp(
      r'''location\.href\s*=\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    ).firstMatch(html);
    if (locationHref != null) {
      return _toAbsolute(locationHref.group(1)!, baseUrl);
    }

    // Anchor fallback
    final anchor = RegExp(
      r'href\s*=\s*"([^"]+)"[^>]*>\s*(?:download|click here)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (anchor != null) {
      return _toAbsolute(anchor.group(1)!, baseUrl);
    }

    return null;
  }

  Map<String, String>? _extractDownloadParams(String html) {
    String? pick(String name) {
      final match = RegExp(
        'name\\s*=\\s*"${RegExp.escape(name)}"\\s+value\\s*=\\s*"([^"]*)"',
        caseSensitive: false,
      ).firstMatch(html);
      return match?.group(1);
    }

    final idurl = pick('idurl');
    final idfilename = pick('idfilename');
    final idfilesize = pick('idfilesize');

    if (idurl == null || idfilename == null || idfilesize == null) {
      return null;
    }

    return {
      'idurl': idurl,
      'idfilename': idfilename,
      'idfilesize': idfilesize,
    };
  }

  Future<String> _callDownloadEndpoint(Map<String, String> params) async {
    final uri = Uri.https('download.megaup.net', '/', params);

    final response = await http.get(
      uri,
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.acceptHeader: 'text/html,application/xhtml+xml',
        HttpHeaders.refererHeader: 'https://megaup.net/',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception(
          'Megaup download endpoint returned ${response.statusCode}');
    }

    return response.body;
  }

  String _toAbsolute(String maybeRelative, String baseUrl) {
    final value = maybeRelative.trim();
    final uri = Uri.parse(value);
    if (uri.hasScheme) return value;
    return Uri.parse(baseUrl).resolveUri(uri).toString();
  }

  Future<void> _checkDownloadUrl(String url, {required String referer}) async {
    final head = await http.head(
      Uri.parse(url),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.refererHeader: referer,
      },
    ).timeout(const Duration(seconds: 30));

    if (head.statusCode == 405) {
      final probe = await http.get(
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
