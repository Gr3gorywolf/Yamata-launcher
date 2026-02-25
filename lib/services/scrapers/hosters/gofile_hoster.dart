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

  // Cache token like Axios
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

      // Same behavior as before
      return '$directUrl||headers:Cookie: accountToken=$token';
    } catch (e) {
      print('[Gofile] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNALS
  // =========================

  String? _extractGofileId(String url) {
    final parts = url.split('/');
    return parts.isNotEmpty ? parts.last : null;
  }

  // Equivalent to Axios authorize() with cached token
  Future<String> _ensureAuthorized() async {
    if (_token != null && _token!.isNotEmpty) {
      return _token!;
    }

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

      _token = token;
      return token;
    }

    throw Exception('Failed to authorize');
  }

  // Equivalent to Axios getDownloadLink()
  Future<String> _getDownloadLink({
    required String id,
    required String token,
  }) async {
    print('[Gofile] Fetching contents for id: $id');

    final response = await http.get(
      Uri.parse('https://api.gofile.io/contents/$id'),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        'X-Website-Token': _websiteToken,
      },
    ).timeout(const Duration(seconds: 30));

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (body['status'] == 'ok') {
      final data = body['data'] as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type != 'folder') {
        throw Exception('Only folders are supported');
      }

      final children = data['children'];
      if (children is! Map || children.isEmpty) {
        throw Exception('Folder is empty or invalid');
      }

      // Same as: Object.values(children)[0]
      final firstChild = children.values.first;
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

  // Equivalent to Axios HEAD check
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
      // Invalidate token (important improvement)
      _token = null;
      throw Exception('Direct url check failed: ${response.statusCode}');
    }
  }
}
