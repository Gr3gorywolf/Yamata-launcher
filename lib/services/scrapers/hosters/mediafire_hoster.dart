import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class MediafireHoster implements Hoster {
  @override
  String get name => 'Mediafire';
  // =========================
  // DOMAINS
  // =========================
  static const List<String> _mediafireDomains = [
    'mediafire.com',
  ];

  // =========================
  // REGEX (portadas desde JS)
  // =========================

  // /^[a-zA-Z0-9]+$/m
  final RegExp validMediafireIdentifierDL = RegExp('^[A-Za-z0-9]+\$');

  // /(['"])(https?:)?(\/\/)?(www\.)?mediafire\.com\/(file|view|download)\/[^'"?]+\?dkey=[^'"]+\1/
  final RegExp validMediafirePreDL = RegExp(
    '(https?:\\/\\/)?(www\\.)?mediafire\\.com\\/(file|view|download)\\/[^\\s\\?]+\\?[^\\s]*dkey=[^\\s]+',
    caseSensitive: false,
  );

  // /(['"])https?:\/\/download\d+\.mediafire\.com\/[^'"]+\1/
  final RegExp validDynamicDL = RegExp(
    'https?:\\/\\/download[0-9]+\\.mediafire\\.com\\/[^\\s]+',
    caseSensitive: false,
  );

  // /^https?:\/\//m
  static final RegExp _checkHttp = RegExp(r'^https?:\/\/', multiLine: true);

  // =========================
  // CONTRACT
  // =========================

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _mediafireDomains.any(lower.contains) ||
        validDynamicDL.hasMatch(url);
  }

  @override
  Future<String?> extractFileName(String url) async {
    try {
      final directUrl = await extractDownloadUrl(url);
      return CommonHosterUtils()
          .extractHosterFilename(url, directUrl: directUrl);
    } catch (e) {
      print('[Mediafire] extractFileName failed: $e');
      return null;
    }
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    try {
      final processedUrl = _processUrl(url);

      print('[Mediafire] Fetching page: $processedUrl');

      final response = await http.get(
        Uri.parse(processedUrl),
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch Mediafire page');
      }

      final html = response.body;
      return _extractDirectUrl(html);
    } catch (e) {
      print('[Mediafire] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
    }
  }

  // =========================
  // INTERNALS
  // =========================

  String _processUrl(String url) {
    var processed = url.replaceFirst('http://', 'https://');

    // JS: /^[a-zA-Z0-9]+$/
    if (validMediafireIdentifierDL.hasMatch(processed)) {
      processed = 'https://mediafire.com/?$processed';
    }

    // JS: /^https?:\/\//
    if (!_checkHttp.hasMatch(processed)) {
      processed = processed.startsWith('//')
          ? 'https:$processed'
          : 'https://$processed';
    }

    return processed;
  }

  String _extractDirectUrl(String html) {
    final preMatch = validMediafirePreDL.firstMatch(html);
    if (preMatch != null && preMatch.groupCount >= 1) {
      return preMatch.group(1)!;
    }

    final dlMatch = validDynamicDL.firstMatch(html);
    if (dlMatch != null && dlMatch.groupCount >= 1) {
      return dlMatch.group(1)!;
    }

    throw Exception('No valid download links found');
  }
}
