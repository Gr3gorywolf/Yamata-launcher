import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class FuckingFastHoster implements Hoster {
  @override
  String get name => 'FuckingFast';
  static const List<String> _fuckingfastDomains = [
    'fuckingfast.co',
    'fuckingfast.net',
  ];

  // JS:
  // /window\.open\("(https:\/\/fuckingfast\.co\/dl\/[^"]*)"\)/
  static final RegExp _downloadRegex = RegExp(
    r'window\.open\("(https:\/\/fuckingfast\.co\/dl\/[^"]*)"\)',
    caseSensitive: false,
  );

  @override
  bool isValidDirectDownloadUrl(String url) {
    return true;
  }

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _fuckingfastDomains.any(lower.contains);
  }

  @override
  Future<HosterMetadata?> extractMetadata(String url) async {
    var extractedUrl = await extractDownloadUrl(url);
    if (extractedUrl == null)
      return HosterMetadata(status: HosterStatus.Invalid);
    CommonHosterUtils.directDownloadUris[url] = extractedUrl;
    return HosterMetadata(
        fileName: await CommonHosterUtils()
            .extractHosterFilename(url, directUrl: extractedUrl),
        status: HosterStatus.Valid);
  }

  // =========================
  // DIRECT DOWNLOAD URL
  // =========================
  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (CommonHosterUtils.directDownloadUris.containsKey(url)) {
      print('[FuckingFast] Using cached direct link');
      return CommonHosterUtils.directDownloadUris[url];
    }
    if (!canHandleUrl(url)) {
      return null;
    }

    print('[FuckingFast] Starting download link extraction for: $url');

    try {
      // -------------------------
      // 1. GET page HTML
      // -------------------------
      final response = await http.get(
        Uri.parse(url),
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        },
      ).timeout(const Duration(seconds: 30));

      final html = response.body;

      // -------------------------
      // 2. Error detection (same as TS)
      // -------------------------
      final lowerHtml = html.toLowerCase();

      if (lowerHtml.contains('rate limit')) {
        print('[FuckingFast] Rate limit detected');
        throw Exception(
          'Rate limit exceeded. Please wait a few minutes and try again.',
        );
      }

      if (html.contains('File Not Found Or Deleted')) {
        print('[FuckingFast] File not found or deleted');
        throw Exception('File not found or deleted');
      }

      // -------------------------
      // 3. Extract direct link
      // -------------------------
      final match = _downloadRegex.firstMatch(html);

      if (match == null || match.groupCount < 1) {
        print('[FuckingFast] Could not extract download link');
        throw Exception('Could not extract download link from page');
      }

      print('[FuckingFast] Successfully extracted direct link');
      return match.group(1);
    } catch (e) {
      print('[FuckingFast] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
    }
  }
}
