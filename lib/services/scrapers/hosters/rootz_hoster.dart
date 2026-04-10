import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class RootzHoster implements Hoster {
  @override
  String get name => 'Rootz';

  static const _primaryDomain = 'rootz.so';

  @override
  bool canHandleUrl(String url) {
    try {
      return Uri.parse(url).host.contains(_primaryDomain);
    } catch (_) {
      return false;
    }
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    return url.isNotEmpty && !canHandleUrl(url);
  }

  @override
  Future<HosterMetadata?> extractMetadata(String url) async {
    var extractedUrl = await extractDownloadUrl(url);
    if (extractedUrl == null)
      return HosterMetadata(status: HosterStatus.Invalid);
    return HosterMetadata(
        fileName: await CommonHosterUtils()
            .extractHosterFilename(url, directUrl: extractedUrl),
        status: HosterStatus.Valid);
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    try {
      final id = _extractId(url);
      final apiUrl = 'https://www.rootz.so/api/files/download-by-short/$id';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
          HttpHeaders.acceptHeader: 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 404) {
        final body = jsonDecode(response.body);
        final errorMessage = body is Map<String, dynamic>
            ? (body['error']?.toString() ?? 'File not found')
            : 'File not found';
        throw Exception(errorMessage);
      }

      final body = jsonDecode(response.body);

      if (body['success'] == true &&
          body['data'] != null &&
          body['data']['url'] != null) {
        final directUrl = body['data']['url'];

        return '$directUrl||headers:User-Agent:${CommonHosterUtils().hosterUserAgent}';
      }

      throw Exception('Failed to get download URL from Rootz API');
    } catch (e) {
      print('[Rootz] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  String _extractId(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments =
          uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

      if (pathSegments.length < 2 || pathSegments[0] != 'd') {
        throw Exception('Invalid rootz URL format');
      }

      return pathSegments[1];
    } catch (_) {
      throw Exception('Invalid rootz URL format');
    }
  }
}
