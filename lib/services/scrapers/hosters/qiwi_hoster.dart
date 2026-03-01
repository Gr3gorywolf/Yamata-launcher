import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class QiwiHoster implements Hoster {
  @override
  String get name => 'Qiwi';

  static const _domains = [
    'qiwi.gg',
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
        throw Exception('Invalid Qiwi URL');
      }

      final extension = await _extractExtension(url);

      final directUrl = 'https://spyderrock.com/$fileId.$extension';

      return '$directUrl||headers:User-Agent: ${CommonHosterUtils().hosterUserAgent}';
    } catch (e) {
      print('[Qiwi] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  String? _extractFileId(String url) {
    final uri = Uri.parse(url);
    if (uri.pathSegments.isEmpty) return null;
    return uri.pathSegments.last;
  }

  Future<String> _extractExtension(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.acceptHeader: 'text/html',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Qiwi page not accessible');
    }

    final document = html_parser.parse(response.body);

    final titleElement = document.querySelector('h1.page_TextHeading__VsM7r');

    if (titleElement == null || titleElement.text.trim().isEmpty) {
      throw Exception('File not found');
    }

    final fileName = titleElement.text.trim();

    if (!fileName.contains('.')) {
      throw Exception('Invalid filename');
    }

    return fileName.split('.').last;
  }
}
