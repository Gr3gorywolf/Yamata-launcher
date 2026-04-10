import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class PixelDrainHoster implements Hoster {
  @override
  String get name => 'PixelDrain';

  static const _primaryDomain = 'pixeldrain.com';
  static const _bypassBaseUrl = 'https://cdn.pixeldrain.eu.cc';
  static const _bypassTimeout = Duration(seconds: 5);

  @override
  bool canHandleUrl(String url) {
    try {
      return Uri.parse(url).host.contains(_primaryDomain);
    } catch (_) {
      return false;
    }
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    return url.contains('pixeldrain.com/api/file/') ||
        url.contains('cdn.pixeldrain.eu.cc/');
  }

  @override
  Future<HosterMetadata?> extractMetadata(String url) async {
    var document = await CommonHosterUtils().fetchHtml(url);
    if (document == null) return HosterMetadata(status: HosterStatus.Invalid);
    var fileName = document.querySelector('title')?.text.trim();
    var status = HosterStatus.Valid;
    if ((document.querySelector('title')?.text?.trim()?.contains("404") ??
        false)) {
      status = HosterStatus.Invalid;
    }
    return HosterMetadata(fileName: fileName, status: status);
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;

    try {
      final fileId = _extractFileId(url);
      final bypassUrl = await _tryBypass(fileId);

      if (bypassUrl != null) {
        return bypassUrl;
      }

      await _checkAvailability(fileId);
      return 'https://pixeldrain.com/api/file/$fileId?download';
    } catch (e) {
      print('[PixelDrain] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  String _extractFileId(String url) {
    try {
      final uri = Uri.parse(url);
      final pathParts =
          uri.pathSegments.where((part) => part.isNotEmpty).toList();
      final id = pathParts.length > 1 ? pathParts[1] : null;

      if (pathParts.isEmpty ||
          pathParts[0] != 'u' ||
          id == null ||
          id.isEmpty) {
        throw Exception('Invalid PixelDrain URL: $url');
      }

      return id;
    } catch (_) {
      throw Exception('Invalid PixelDrain URL: $url');
    }
  }

  Future<void> _checkAvailability(String id) async {
    final response = await http.head(
      Uri.parse('https://pixeldrain.com/u/$id'),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      },
    );

    if (response.statusCode == 404) {
      throw Exception('File not found');
    }
  }

  String _getBypassUrl(String id) {
    return '$_bypassBaseUrl/$id';
  }

  Future<String?> _tryBypass(String id) async {
    final bypassUrl = _getBypassUrl(id);

    try {
      final response = await http.head(
        Uri.parse(bypassUrl),
        headers: {
          HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
        },
      ).timeout(_bypassTimeout);

      if (response.statusCode >= 200 && response.statusCode < 400) {
        return bypassUrl;
      }

      print(
        '[PixelDrain] Bypass HEAD returned status ${response.statusCode}, falling back to API resolver.',
      );
      return null;
    } catch (_) {
      print('[PixelDrain] Bypass HEAD failed, falling back to API resolver.');
      return null;
    }
  }
}
