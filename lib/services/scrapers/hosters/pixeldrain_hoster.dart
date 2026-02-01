import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class PixelDrainHoster implements Hoster {
  @override
  String get name => 'PixelDrain';

  static const List<String> _pixeldrainDomains = [
    'pixeldrain.com',
    'pd.cybar.xyz',
  ];

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _pixeldrainDomains.any(lower.contains);
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
      print('[PixelDrain] extractFileName failed: $e');
      return null;
    }
  }

  // =========================
  // DIRECT DOWNLOAD URL
  // =========================
  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    print('[PixelDrain] Starting download link extraction for: $url');

    try {
      final fileId = _extractFileId(url);
      if (fileId == null || fileId.isEmpty) {
        throw Exception('Could not extract PixelDrain file id');
      }

      final requestUrl = 'https://pd.cybar.xyz/$fileId';
      print('[PixelDrain] GET (no redirects): $requestUrl');

      final response = await http
          .get(
            Uri.parse(requestUrl),
            headers: _browserHeaders(),
          )
          .timeout(const Duration(seconds: 30));

      // http NO sigue redirects automáticamente en Dart
      final location = response.headers['location'];

      if (location != null && location.isNotEmpty) {
        print('[PixelDrain] Redirect detected → $location');
        return location;
      }

      if (response.statusCode == 200) {
        throw Exception(
          'No redirect URL found (status: 200)',
        );
      }

      throw Exception(
        'No redirect URL found (status: ${response.statusCode})',
      );
    } catch (e) {
      print('[PixelDrain] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
    }
  }

  // =========================
  // INTERNALS
  // =========================

  String? _extractFileId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // https://pixeldrain.com/u/<id>
    // https://pd.cybar.xyz/<id>
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (segments.isEmpty) return null;

    // pixeldrain.com/u/<id>
    if (segments.length >= 2 && segments.first == 'u') {
      return segments[1];
    }

    // pd.cybar.xyz/<id>
    return segments.first;
  }

  Map<String, String> _browserHeaders() {
    return {
      HttpHeaders.userAgentHeader: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/121.0.0.0 Safari/537.36',
      HttpHeaders.acceptHeader:
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
      HttpHeaders.acceptLanguageHeader: 'en-US,en;q=0.9',
      'DNT': '1',
      HttpHeaders.connectionHeader: 'keep-alive',
    };
  }
}
