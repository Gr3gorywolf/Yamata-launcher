import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class RootzHoster implements Hoster {
  static const List<String> _rootzDomains = [
    'rootz.so',
    'www.rootz.so',
  ];

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _rootzDomains.any(lower.contains);
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
      print('[Rootz] extractFileName failed: $e');
      return null;
    }
  }

  // =========================
  // DIRECT DOWNLOAD URL
  // =========================
  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    print('[Rootz] Starting download link extraction for: $url');

    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

      // TS:
      // if (pathSegments.length < 2 || pathSegments[0] !== "d")
      if (segments.length < 2 || segments.first != 'd') {
        throw Exception('Invalid rootz URL format');
      }

      final id = segments[1];
      final apiUrl = 'https://www.rootz.so/api/files/download-by-short/$id';

      print('[Rootz] Calling API: $apiUrl');

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 404) {
        final body = _safeJson(response.body);
        final message = body?['error']?.toString() ?? 'File not found';
        print('[Rootz] $message');
        throw Exception(message);
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Unexpected status code: ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is Map &&
          decoded['success'] == true &&
          decoded['data'] is Map &&
          decoded['data']['url'] is String) {
        final directUrl = decoded['data']['url'] as String;
        print('[Rootz] Extracted direct link');
        return directUrl;
      }

      throw Exception('Failed to get download URL from rootz API');
    } catch (e) {
      print('[Rootz] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
    }
  }

  // =========================
  // INTERNALS
  // =========================
  Map<String, dynamic>? _safeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
