import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class MegaCoNzHoster implements Hoster {
  @override
  String get name => 'MegaCoNz';

  static const List<String> _domains = [
    'mega.nz',
    'mega.co.nz',
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
      print('[MegaCoNz] extractFileName failed: $e');
      return null;
    }
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    try {
      final fileId = _extractPublicFileId(url);
      if (fileId == null || fileId.isEmpty) {
        throw Exception('Unsupported MEGA URL (file id not found)');
      }

      final directUrl = await _getDirectLink(fileId);
      await _checkDownloadUrl(directUrl);

      return directUrl;
    } catch (e) {
      print('[MegaCoNz] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  String? _extractPublicFileId(String url) {
    final uri = Uri.parse(url.trim());
    final seg = uri.pathSegments;

    // New style: /file/<id>#<key>
    if (seg.length >= 2 && (seg[0] == 'file' || seg[0] == 'embed')) {
      return seg[1];
    }

    // Old style: /#!<id>!<key> OR /#F!... (folder -> unsupported here)
    final oldStyle = RegExp(r'#!([a-zA-Z0-9_-]{6,})!').firstMatch(url);
    if (oldStyle != null) {
      return oldStyle.group(1);
    }

    // Some copied links contain "/file/<id>" without key
    final loose = RegExp(r'/file/([a-zA-Z0-9_-]{6,})').firstMatch(url);
    return loose?.group(1);
  }

  Future<String> _getDirectLink(String fileId) async {
    final id = Random().nextInt(9000000) + 1000000;
    final endpoint = Uri.parse('https://g.api.mega.co.nz/cs?id=$id');

    final payloadP = [
      {'a': 'g', 'g': 1, 'p': fileId}
    ];
    final firstTry = await _postMega(endpoint, payloadP);
    final linkFromP = _extractMegaLink(firstTry);
    if (linkFromP != null) return linkFromP;

    final payloadN = [
      {'a': 'g', 'g': 1, 'n': fileId}
    ];
    final secondTry = await _postMega(endpoint, payloadN);
    final linkFromN = _extractMegaLink(secondTry);
    if (linkFromN != null) return linkFromN;

    throw Exception('Failed to resolve MEGA direct link');
  }

  Future<dynamic> _postMega(
      Uri endpoint, List<Map<String, dynamic>> body) async {
    final response = await http
        .post(
          endpoint,
          headers: {
            HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.acceptHeader: 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('MEGA API returned ${response.statusCode}');
    }

    return jsonDecode(response.body);
  }

  String? _extractMegaLink(dynamic decoded) {
    if (decoded is! List || decoded.isEmpty) return null;
    final first = decoded.first;

    if (first is int) {
      // Negative integer = MEGA API error code.
      throw Exception('MEGA API error code: $first');
    }

    if (first is! Map<String, dynamic>) return null;

    if (first['e'] != null) {
      throw Exception('MEGA API payload error: ${first['e']}');
    }

    final g = first['g'];
    if (g is String && g.isNotEmpty) return g;

    return null;
  }

  Future<void> _checkDownloadUrl(String url) async {
    final uri = Uri.parse(url);

    final head = await http.head(
      uri,
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      },
    ).timeout(const Duration(seconds: 30));

    if (head.statusCode == 405) {
      final probe = await http.get(
        uri,
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
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
