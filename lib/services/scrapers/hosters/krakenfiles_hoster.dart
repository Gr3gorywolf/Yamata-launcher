import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class KrakenfilesHoster implements Hoster {
  @override
  String get name => 'Krakenfiles';

  static const _domains = [
    'krakenfiles.com',
  ];

  @override
  bool canHandleUrl(String url) {
    return _domains.any((d) => url.toLowerCase().contains(d));
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
      final pageHtml = await _loadPage(url);

      final postInfo = _extractFormData(pageHtml);
      if (postInfo == null) {
        throw Exception('Unable to find download form');
      }

      final directUrl = await _requestDownloadUrl(
        postInfo.postUrl,
        postInfo.token,
        referer: url,
      );

      return '$directUrl||headers:Referer:$url^User-Agent:${CommonHosterUtils().hosterUserAgent}';
    } catch (e) {
      print('[Krakenfiles] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  Future<String> _loadPage(String url) async {
    final res = await http.get(
      Uri.parse(url),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      },
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode >= 400) {
      throw Exception('Failed to load Krakenfiles page');
    }

    return res.body;
  }

  _KrakenFormData? _extractFormData(String html) {
    final document = html_parser.parse(html);

    final form = document.querySelector('#dl-form');
    if (form == null) return null;

    final action = form.attributes['action'];
    if (action == null || action.isEmpty) return null;

    final tokenElement = document.querySelector('#dl-token');
    final token = tokenElement?.attributes['value'];

    if (token == null || token.isEmpty) return null;

    final postUrl =
        action.startsWith('http') ? action : 'https://krakenfiles.com$action';

    return _KrakenFormData(postUrl, token);
  }

  Future<String> _requestDownloadUrl(
    String postUrl,
    String token, {
    required String referer,
  }) async {
    final res = await http.post(
      Uri.parse(postUrl),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.refererHeader: referer,
        HttpHeaders.contentTypeHeader: 'application/x-www-form-urlencoded',
      },
      body: {
        'token': token,
      },
    ).timeout(const Duration(seconds: 30));

    final body = jsonDecode(res.body);

    if (body['status'] != 'ok' || body['url'] == null) {
      throw Exception('Krakenfiles download URL not found');
    }

    return body['url'];
  }
}

// =========================
// MODEL
// =========================

class _KrakenFormData {
  final String postUrl;
  final String token;

  _KrakenFormData(this.postUrl, this.token);
}
