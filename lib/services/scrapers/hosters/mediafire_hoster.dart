import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class MediafireHoster implements Hoster {
  @override
  String get name => 'Mediafire';

  static const _domains = ['mediafire.com'];

  // Regex del código original
  static final _validIdentifier = RegExp(r'^[a-zA-Z0-9]+$');
  static final _validPreDL = RegExp(
    r'''(?<=['"])(https?:)?(\/\/)?(www\.)?mediafire\.com\/(file|view|download)\/[^'"?]+\?dkey=[^'"]+(?=['"])''',
    multiLine: true,
  );

  static final _validDynamicDL = RegExp(
    r'''(?<=['"])https?:\/\/download\d+\.mediafire\.com\/[^'"]+(?=['"])''',
    multiLine: true,
  );

  @override
  bool canHandleUrl(String url) {
    return _domains.any((d) => url.toLowerCase().contains(d));
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
      final processedUrl = _processUrl(url);

      final response = await http.get(
        Uri.parse(processedUrl),
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode >= 400) {
        throw Exception('Failed to fetch Mediafire page');
      }

      final html = response.body;

      final directUrl = _extractDirectUrl(html);

      return '$directUrl||headers:User-Agent:${CommonHosterUtils().hosterUserAgent}';
    } catch (e) {
      print('[Mediafire] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  String _processUrl(String url) {
    var processed = url.replaceFirst('http://', 'https://');

    // Caso: solo ID
    final uri = Uri.tryParse(processed);
    if (uri != null &&
        uri.host.isEmpty &&
        _validIdentifier.hasMatch(processed)) {
      processed = 'https://mediafire.com/?$processed';
    }

    if (!processed.startsWith('http')) {
      if (processed.startsWith('//')) {
        processed = 'https:$processed';
      } else {
        processed = 'https://$processed';
      }
    }

    return processed;
  }

  String _extractDirectUrl(String html) {
    final preMatch = _validPreDL.firstMatch(html);
    if (preMatch != null) {
      var url = preMatch.group(0)!;
      if (url.startsWith('//')) {
        url = 'https:$url';
      }
      return url;
    }

    final dlMatch = _validDynamicDL.firstMatch(html);
    if (dlMatch != null) {
      return dlMatch.group(0)!;
    }

    throw Exception('No valid download links found');
  }
}
