import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class GoogleDriveHoster implements Hoster {
  @override
  String get name => 'Google Drive';

  static const _base = 'https://drive.usercontent.google.com/download';

  final Map<String, String> _cookies = {};

  @override
  bool canHandleUrl(String url) {
    return url.toLowerCase().contains('drive.google.com');
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    return url.contains('googleusercontent.com');
  }

  @override
  Future<HosterMetadata?> extractMetadata(String url) async {
    var document = await CommonHosterUtils().fetchHtml(url);
    if (document == null) return HosterMetadata(status: HosterStatus.Invalid);
    var fileName = document
        .querySelector('head > title')
        ?.text
        .trim()
        .split(' - Google Drive')
        .first;
    var status = HosterStatus.Valid;
    if (document.querySelector(".errorMessage") != null) {
      status = HosterStatus.Invalid;
    }
    return HosterMetadata(fileName: fileName, status: status);
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    try {
      final id = _extractFileId(url);
      if (id == null) {
        throw Exception('Invalid Google Drive URL');
      }

      // 1️⃣ Initial request (this triggers virus page if needed)
      final initialUri = Uri.parse(_base).replace(queryParameters: {
        'id': id,
        'authuser': '0',
        'confirm': 't',
      });

      final res = await _request(initialUri.toString());

      // If already a file response
      if (res.headers.containsKey('content-disposition')) {
        return _withHeaders(res.request!.url.toString(), referer: url);
      }

      final body = res.body;

      // 2️⃣ Parse form
      final doc = parser.parse(body);
      final form = doc.querySelector('#download-form');

      if (form == null) {
        throw Exception('File not found');
      }

      final action = form.attributes['action'];
      if (action == null) {
        throw Exception('Google Drive form action missing');
      }

      final inputs = form.querySelectorAll('input');
      final params = <String, String>{};

      for (final input in inputs) {
        final name = input.attributes['name'];
        final value = input.attributes['value'];
        if (name != null && value != null) {
          params[name] = value;
        }
      }

      // 3️⃣ Build final URL
      final finalUrl =
          Uri.parse(action).replace(queryParameters: params).toString();

      return _withHeaders(finalUrl, referer: url);
    } catch (e) {
      print('[GoogleDrive] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // REQUEST
  // =========================

  Future<http.Response> _request(String url) async {
    final res = await http.get(
      Uri.parse(url),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        if (_cookies.isNotEmpty)
          HttpHeaders.cookieHeader:
              _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
      },
    ).timeout(const Duration(seconds: 30));

    _storeCookies(res);
    return res;
  }

  void _storeCookies(http.Response res) {
    final setCookie = res.headers['set-cookie'];
    if (setCookie == null) return;

    final parts = setCookie.split(',');
    for (final part in parts) {
      final cookie = part.split(';').first;
      final kv = cookie.split('=');
      if (kv.length == 2) {
        _cookies[kv[0].trim()] = kv[1].trim();
      }
    }
  }

  // =========================
  // HELPERS
  // =========================

  String? _extractFileId(String url) {
    final patterns = [
      RegExp(r'/file/d/([a-zA-Z0-9_-]+)'),
      RegExp(r'id=([a-zA-Z0-9_-]+)'),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  String _withHeaders(String url, {required String referer}) {
    return '$url||headers:Referer:$referer^User-Agent:${CommonHosterUtils().hosterUserAgent}';
  }
}
