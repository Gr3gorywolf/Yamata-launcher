import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class MegaHoster implements Hoster {
  String get name => 'MEGA';

  static const _domains = [
    'mega.nz',
    'mega.co.nz',
  ];

  final _userAgent = 'Mozilla/5.0';

  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _domains.any(lower.contains);
  }

  Future<String?> extractDownloadUrl(String url) async {
    if (CommonHosterUtils.directDownloadUris.containsKey(url)) {
      print('[MEGA] Using cached direct link');
      return CommonHosterUtils.directDownloadUris[url];
    }
    if (!canHandleUrl(url)) return null;

    try {
      final parsed = _parseMegaUrl(url);
      if (parsed == null) {
        throw Exception('Invalid MEGA URL');
      }

      final info = await _getDownloadInfo(parsed.fileId);

      final fileName = _decryptFileName(
        parsed.fileKey,
        info.encryptedAttributes,
      );

      final safeName = _sanitizeFilename(fileName ?? 'mega_file');

      return '${info.url}||filename:$safeName||headers:User-Agent: $_userAgent';
    } catch (e) {
      print('[MEGA ERROR] $e');
      return null;
    }
  }

  @override
  Future<HosterMetadata?> extractMetadata(String url) async {
    var extractedUrl = await extractDownloadUrl(url);
    if (extractedUrl == null)
      return HosterMetadata(status: HosterStatus.Invalid);
    CommonHosterUtils.directDownloadUris[url] = extractedUrl;
    return HosterMetadata(
        fileName: await CommonHosterUtils()
            .extractHosterFilename(url, directUrl: extractedUrl),
        status: HosterStatus.Valid);
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    return url.contains('mega.nz') || url.contains('mega.co.nz');
  }

  // =========================
  // URL PARSER
  // =========================

  _MegaLinkData? _parseMegaUrl(String url) {
    final uri = Uri.parse(url);

    // Modern format
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'file') {
      return _MegaLinkData(
        uri.pathSegments[1],
        uri.fragment,
      );
    }

    // Old format
    if (uri.fragment.contains('!')) {
      final parts = uri.fragment.split('!');
      if (parts.length >= 3) {
        return _MegaLinkData(parts[1], parts[2]);
      }
    }

    return null;
  }

  // =========================
  // API CALL
  // =========================

  Future<MegaDownloadInfo> _getDownloadInfo(String fileId) async {
    final seq = Random().nextInt(999999);

    final body = jsonEncode([
      {
        "a": "g",
        "g": 1,
        "p": fileId,
      }
    ]);

    final response = await http.post(
      Uri.parse('https://g.api.mega.co.nz/cs?id=$seq'),
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
        HttpHeaders.userAgentHeader: _userAgent,
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final jsonResponse = jsonDecode(response.body);
    final data = jsonResponse[0];

    if (data['e'] != null) {
      throw Exception('MEGA error ${data['e']}');
    }

    return MegaDownloadInfo(
      data['g'],
      data['at'],
    );
  }

  // =========================
  // DECRYPT FILENAME
  // =========================

  String? _decryptFileName(String fileKey, String encryptedAttributes) {
    try {
      final keyBytes = _base64UrlDecode(fileKey);
      final key = keyBytes.sublist(0, 16);

      final cipher = CBCBlockCipher(AESEngine())
        ..init(
          false,
          ParametersWithIV(
            KeyParameter(key),
            Uint8List(16),
          ),
        );

      final encrypted = _base64UrlDecode(encryptedAttributes);
      final padded = _processBlocks(cipher, encrypted);

      final jsonString = utf8.decode(padded).replaceAll('\u0000', '');

      if (!jsonString.startsWith('MEGA')) return null;

      final jsonPart = jsonString.substring(4);
      final decoded = jsonDecode(jsonPart);

      return decoded['n'];
    } catch (_) {
      return null;
    }
  }

  Uint8List _processBlocks(BlockCipher cipher, Uint8List input) {
    final output = Uint8List(input.length);
    for (var offset = 0; offset < input.length;) {
      offset += cipher.processBlock(input, offset, output, offset);
    }
    return output;
  }

  Uint8List _base64UrlDecode(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');

    while (normalized.length % 4 != 0) {
      normalized += '=';
    }

    return base64.decode(normalized);
  }

  // =========================
  // UTIL
  // =========================

  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }
}

class _MegaLinkData {
  final String fileId;
  final String fileKey;

  _MegaLinkData(this.fileId, this.fileKey);
}

class MegaDownloadInfo {
  final String url;
  final String encryptedAttributes;

  MegaDownloadInfo(this.url, this.encryptedAttributes);
}
