import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/exceptions/download_require_manual_exception.dart';
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
    return url.contains("gofile.io/download/web");
  }

  @override
  Future<HosterMetadata?> extractMetadata(String url) async {
    return HosterMetadata(status: HosterStatus.NeedsManual);
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (CommonHosterUtils.directDownloadUris.containsKey(url)) {
      print('[GoFile] Using cached direct link');
      return CommonHosterUtils.directDownloadUris[url];
    }
    throw DownloadRequireManualException(
        'GoFile requires manual download due to potential anti-bot measures. Please visit the link and download the file manually.');
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
