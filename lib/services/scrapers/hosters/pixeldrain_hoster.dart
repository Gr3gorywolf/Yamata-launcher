import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class PixelDrainHoster implements Hoster {
  @override
  String get name => 'PixelDrain';

  static const List<String> _domains = [
    'pixeldrain.com',
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
      print('[PixelDrain] extractFileName failed: $e');
      return null;
    }
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    try {
      final parsed = Uri.parse(url.trim());
      final idInfo = _extractId(parsed);

      if (idInfo == null) {
        throw Exception('Could not extract PixelDrain id from url');
      }

      late final String directUrl;

      if (idInfo.type == _PixelDrainType.file) {
        directUrl = 'https://pixeldrain.com/api/file/${idInfo.id}?download';
      } else {
        final fileId = await _getFirstFileIdFromList(idInfo.id);
        directUrl = 'https://pixeldrain.com/api/file/$fileId?download';
      }

      await _checkDownloadUrl(directUrl);

      return directUrl;
    } catch (e) {
      print('[PixelDrain] Error in extractDownloadUrl: $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  _PixelDrainId? _extractId(Uri uri) {
    final seg = uri.pathSegments;
    if (seg.length < 2) return null;

    // https://pixeldrain.com/u/<id>
    if (seg[0] == 'u' && seg[1].isNotEmpty) {
      return _PixelDrainId(type: _PixelDrainType.file, id: seg[1]);
    }

    // https://pixeldrain.com/l/<id>
    if (seg[0] == 'l' && seg[1].isNotEmpty) {
      return _PixelDrainId(type: _PixelDrainType.list, id: seg[1]);
    }

    return null;
  }

  Future<String> _getFirstFileIdFromList(String listId) async {
    final response = await http.get(
      Uri.parse('https://pixeldrain.com/api/list/$listId'),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        HttpHeaders.acceptHeader: 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('List lookup failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final files = body['files'];

    if (files is! List || files.isEmpty) {
      throw Exception('PixelDrain list is empty or invalid');
    }

    final first = files.first;
    if (first is! Map<String, dynamic>) {
      throw Exception('Invalid list file payload');
    }

    final fileId = first['id'] as String?;
    if (fileId == null || fileId.isEmpty) {
      throw Exception('No file id found in list');
    }

    return fileId;
  }

  Future<void> _checkDownloadUrl(String url) async {
    final response = await http.head(
      Uri.parse(url),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode >= 400) {
      throw Exception('Direct url check failed: ${response.statusCode}');
    }
  }
}

enum _PixelDrainType { file, list }

class _PixelDrainId {
  final _PixelDrainType type;
  final String id;

  _PixelDrainId({
    required this.type,
    required this.id,
  });
}
