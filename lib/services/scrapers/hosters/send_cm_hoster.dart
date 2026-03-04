import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/exceptions/download_require_manual_exception.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class SendCmHoster implements Hoster {
  @override
  String get name => 'Send.cm';

  static const _domains = ['send.cm', 'send.now'];

  static const _baseUrl = 'https://send.cm/';

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _domains.any(lower.contains);
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
      if (url.contains('/d/')) {
        final id = _extractId(url);
        final link = await _getFileLink(id, url);
        return _format(link);
      }

      if (!url.contains('/s/')) {
        final id = _extractId(url);
        final link = await _getFileLink(id, url);
        return _format(link);
      }

      final firstId = await _extractFirstFileFromFolder(url);
      if (firstId == null) {
        throw Exception('Folder is empty');
      }

      final link = await _getFileLink(firstId, url);
      return _format(link);
    } catch (e) {
      print('[Send.cm] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  String _extractId(String url) {
    final uri = Uri.parse(url);
    return uri.pathSegments.last;
  }

  Future<String> _getFileLink(String fileId, String url) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.refererHeader: _baseUrl,
      },
      body: {
        'op': 'download2',
        'id': fileId,
      },
    ).timeout(const Duration(seconds: 10));

    final location = response.headers['location'];

    if (location == null || location.isEmpty) {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
          HttpHeaders.acceptHeader: 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 404) {
        throw Exception('File not found');
      }
      if (response.body
          .contains("The file you were looking for doesn't exist.")) {
        throw Exception('File not found or deleted');
      }

      if (response.body.contains("Security verification")) {
        throw DownloadRequireManualException(
            'Download requires manual verification. Please download the file manually.');
      }

      throw Exception('Direct link not found');
    }

    return location;
  }

  Future<String?> _extractFirstFileFromFolder(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Folder page not accessible');
    }

    final document = html_parser.parse(response.body);

    final linkElement = document.querySelector(
      'tr.selectable a',
    );

    if (linkElement == null) return null;

    final href = linkElement.attributes['href'];
    if (href == null) return null;

    final uri = Uri.parse(href);
    return uri.pathSegments.last;
  }

  String _format(String url) {
    return '$url||headers:Referer: https://send.cm/^User-Agent: ${CommonHosterUtils().hosterUserAgent}';
  }
}
