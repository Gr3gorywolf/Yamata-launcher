import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class MegaupHoster implements Hoster {
  @override
  String get name => 'Megaup';

  static const _domains = ['megaup.net'];

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _domains.any(lower.contains);
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
      final page = await _getPage(url);

      // 1️⃣ Wait time
      final wait = _extractWait(page);
      if (wait > 0 && wait <= 30) {
        await Future.delayed(Duration(seconds: wait));
      }

      // 2️⃣ Extract encrypted params
      final params = _extractParams(page);
      if (params == null) {
        throw Exception('Megaup params not found');
      }

      // 3️⃣ Call download endpoint
      final link = await _getDownloadLink(params);

      return '$link||headers:Referer:$url^User-Agent:${CommonHosterUtils().hosterUserAgent}';
    } catch (e) {
      print('[Megaup] $e');
      CommonHosterUtils().handleHosterError(e);
      return null;
    }
  }

  // =========================
  // INTERNAL
  // =========================

  Future<String> _getPage(String url) async {
    final res = await http.get(
      Uri.parse(url),
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      },
    ).timeout(const Duration(seconds: 30));

    if (res.statusCode >= 400) {
      throw Exception('Megaup page error');
    }

    return res.body;
  }

  int _extractWait(String html) {
    final match = RegExp(r'var seconds = (\d+);').firstMatch(html);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  Map<String, String>? _extractParams(String html) {
    // Megaup usually has this pattern after deobfuscation
    final idMatch = RegExp(r'name="idurl"\s+value="([^"]+)"').firstMatch(html);
    final nameMatch =
        RegExp(r'name="idfilename"\s+value="([^"]+)"').firstMatch(html);
    final sizeMatch =
        RegExp(r'name="idfilesize"\s+value="([^"]+)"').firstMatch(html);

    if (idMatch == null) return null;

    return {
      'idurl': idMatch.group(1)!,
      if (nameMatch != null) 'idfilename': nameMatch.group(1)!,
      if (sizeMatch != null) 'idfilesize': sizeMatch.group(1)!,
    };
  }

  Future<String> _getDownloadLink(Map<String, String> params) async {
    final uri = Uri.parse('https://download.megaup.net/')
        .replace(queryParameters: params);

    final res = await http.get(
      uri,
      headers: {
        HttpHeaders.userAgentHeader: CommonHosterUtils().hosterUserAgent,
      },
    ).timeout(const Duration(seconds: 30));

    final match =
        RegExp(r'window.location.replace\("(.+?)"\)').firstMatch(res.body);

    if (match == null) {
      throw Exception('Direct link not found');
    }

    return match.group(1)!;
  }
}
