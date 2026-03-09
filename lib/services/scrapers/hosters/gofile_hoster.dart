import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class GofileHoster implements Hoster {
  @override
  String get name => 'GoFile';

  static const _domains = ['gofile.io'];
  static const _websiteToken = 'XFyAy8TSbDhAIK898yYL0gjVjpp1mwwA';

  static String? _token;

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
    var extractedUrl =
        await extractDownloadUrl(url).timeout(Duration(seconds: 2));
    if (extractedUrl == null)
      return HosterMetadata(status: HosterStatus.Invalid);
    CommonHosterUtils.directDownloadUris[url] = extractedUrl;
    return HosterMetadata(
        fileName: await CommonHosterUtils()
            .extractHosterFilename(url, directUrl: extractedUrl),
        status: HosterStatus.Valid);
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (CommonHosterUtils.directDownloadUris.containsKey(url)) {
      print('[GoFile] Using cached direct link');
      return CommonHosterUtils.directDownloadUris[url];
    }
    if (!canHandleUrl(url)) return null;
    try {
      final id = Uri.parse(url).pathSegments.last;

      final token = await _authorize();

      final link = await _getDownloadLink(id, token);

      await _checkDownloadUrl(link, token);

      return '$link||headers:Cookie: accountToken=$token^User-Agent: ${CommonHosterUtils().hosterUserAgent}';
    } catch (e) {
      print('[GoFile] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  Future<String> _authorize() async {
    if (_token != null && _token!.isNotEmpty) {
      return _token!;
    }

    final response = await http.get(
      Uri.parse('https://api.gofile.io/accounts/website'),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.authorizationHeader: "Bearer ${_websiteToken}"
      },
    );

    final body = jsonDecode(response.body);

    if (body['status'] != 'ok') {
      throw Exception('Failed to authorize');
    }

    _token = body['data']['token'];
    return _token!;
  }

  Future<String> _getDownloadLink(String id, String token) async {
    final response = await http.get(
      Uri.parse('https://api.gofile.io/contents/$id'),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $token',
        'X-Website-Token': _websiteToken,
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      },
    );

    final body = jsonDecode(response.body);

    if (body['status'] != 'ok') {
      throw Exception('Failed to get download link');
    }

    final data = body['data'];

    if (data['type'] != 'folder') {
      throw Exception('Only folders are supported');
    }

    final children = data['children'] as Map<String, dynamic>;
    if (children.isEmpty) {
      throw Exception('Folder is empty');
    }

    final firstChild = children.values.first;
    final link = firstChild['link'];

    if (link == null || link.isEmpty) {
      throw Exception('Invalid file link');
    }

    return link;
  }

  Future<void> _checkDownloadUrl(String url, String token) async {
    final response = await http.head(
      Uri.parse(url),
      headers: {
        HttpHeaders.cookieHeader: 'accountToken=$token',
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode >= 400) {
      _token = null; // invalidate token
      throw Exception('Download URL check failed (${response.statusCode})');
    }
  }
}
