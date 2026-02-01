import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class GofileHoster implements Hoster {
  @override
  String get name => 'GoFile';
  static const List<String> _gofileDomains = [
    'gofile.io',
  ];

  static const String _websiteToken = '4fd6sg89d7s6';

  static String? _token;

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _gofileDomains.any(lower.contains);
  }

  // =========================
  // PUBLIC: filename
  // =========================
  @override
  Future<String?> extractFileName(String url) async {
    try {
      final directUrl = await extractDownloadUrl(url);
      return CommonHosterUtils()
          .extractHosterFilename(url, directUrl: directUrl);
    } catch (e) {
      print('[Gofile] extractFileName failed: $e');
      return null;
    }
  }

  // =========================
  // PUBLIC: direct download url
  // =========================
  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    try {
      final id = _extractGofileId(url);
      if (id == null || id.isEmpty) {
        throw Exception('Could not extract gofile id from url');
      }

      final token = await _ensureAuthorized();

      final directUrl = await _getDownloadLink(
        id: id,
        token: token,
      );

      await _checkDownloadUrl(directUrl, token);

      return directUrl + "||headers:Cookie: accountToken=$token";
    } catch (e) {
      ('[Gofile] Error in extractDownloadUrl', e);
      CommonHosterUtils().handleHosterError(e);
    }
  }

  // =========================
  // INTERNALS
  // =========================

  String? _extractGofileId(String url) {
    return url.split("/").last;
  }

  Future<String> _ensureAuthorized() async {
    print('[Gofile] Authorizing...');

    final response = await http
        .post(Uri.parse('https://api.gofile.io/accounts'))
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body['status'] == 'ok') {
      final data = body['data'] as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('Authorize returned empty token');
      }
      return token;
    }

    throw Exception('Failed to authorize');
  }

  Future<String> _getDownloadLink({
    required String id,
    required String token,
  }) async {
    print('[Gofile] Fetching contents for id: $id');

    final response = await http.get(
      Uri.parse('https://api.gofile.io/contents/$id'),
      headers: {
        "Authorization": 'Bearer $token',
        'X-Website-Token': _websiteToken,
      },
    ).timeout(const Duration(seconds: 30));
    print('[Gofile] Contents response status: ${response.body}');
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body['status'] == 'ok') {
      final data = body['data'] as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type != 'folder') {
        throw Exception('Only folders are supported');
      }

      final childrenRaw = data['children'];
      if (childrenRaw is! Map) {
        throw Exception('Invalid children payload');
      }

      if (childrenRaw.isEmpty) {
        throw Exception('Folder is empty');
      }

      // TS: const [firstChild] = Object.values(children);
      final firstChild = childrenRaw.values.first;
      if (firstChild is! Map) {
        throw Exception('Invalid child payload');
      }

      final link = firstChild['link'] as String?;
      if (link == null || link.isEmpty) {
        throw Exception('Child link not found');
      }

      print('[Gofile] Extracted direct link');
      return link;
    }

    throw Exception('Failed to get download link');
  }

  Future<void> _checkDownloadUrl(String url, String token) async {
    print('[Gofile] Checking direct url (HEAD): $url');

    final response = await http.head(
      Uri.parse(url),
      headers: {
        HttpHeaders.cookieHeader: 'accountToken=$token',
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Direct url check failed: ${response.statusCode}');
    }
  }
}
