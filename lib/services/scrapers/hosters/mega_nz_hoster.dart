import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class MegaHoster implements Hoster {
  @override
  String get name => 'MEGA';

  static const _domains = [
    'mega.nz',
    'mega.co.nz',
  ];

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _domains.any(lower.contains);
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    return true;
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
      final fileId = _extractFileId(url);
      if (fileId == null) {
        throw Exception('Invalid MEGA link');
      }

      final downloadUrl = await _getDownloadUrl(fileId);

      return '$downloadUrl||headers:User-Agent: ${CommonHosterUtils().hosterUserAgent}';
    } catch (e) {
      print('[MEGA] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  String? _extractFileId(String url) {
    // soporta:
    // https://mega.nz/file/XXXX#KEY
    // https://mega.nz/#!XXXX!KEY

    final uri = Uri.parse(url);

    if (uri.fragment.contains('!')) {
      final parts = uri.fragment.split('!');
      if (parts.length >= 2) return parts[1];
    }

    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'file') {
      return segments[1];
    }

    return null;
  }

  Future<String> _getDownloadUrl(String fileId) async {
    final seq = Random().nextInt(1000000);

    final body = jsonEncode([
      {
        "a": "g",
        "g": 1,
        "p": fileId,
      }
    ]);

    final response = await http
        .post(
          Uri.parse('https://g.api.mega.co.nz/cs?id=$seq'),
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    final json = jsonDecode(response.body);

    if (json is! List || json.isEmpty) {
      throw Exception('Invalid MEGA API response');
    }

    final data = json[0];

    if (data['e'] != null) {
      throw Exception('MEGA error: ${data['e']}');
    }

    final link = data['g'];
    if (link == null) {
      throw Exception('Direct link not available');
    }

    return link;
  }
}
