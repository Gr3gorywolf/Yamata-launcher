import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class RootzHoster implements Hoster {
  @override
  String get name => 'Rootz';

  static const _domains = [
    'rootz.so',
  ];

  @override
  bool canHandleUrl(String url) {
    return _domains.any((d) => url.toLowerCase().contains(d));
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    return true;
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
      if (id == null) {
        throw Exception('Invalid Rootz URL');
      }

      final apiUrl = 'https://www.rootz.so/api/files/download-by-short/$id';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
          HttpHeaders.acceptHeader: 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 404) {
        throw Exception('File not found');
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

  String? _extractId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;

      if (segments.length >= 2 && segments[0] == 'd') {
        return segments[1];
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
