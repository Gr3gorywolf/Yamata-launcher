import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/exceptions/download_require_manual_exception.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class OneFichierHoster implements Hoster {
  @override
  String get name => '1Fichier';

  static const _domains = ['1fichier.com'];

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _domains.any(lower.contains);
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    return url.contains(".1fichier.com");
  }

  @override
  Future<HosterMetadata?> extractMetadata(String url) async {
    var document = await CommonHosterUtils().fetchHtml(url);
    if (document == null) return HosterMetadata(status: HosterStatus.Invalid);
    var fileName = document
        .querySelector('tbody > tr > td.normal > span:nth-child(1)')
        ?.text
        .trim();
    var status = HosterStatus.NeedsManual;
    return HosterMetadata(fileName: fileName, status: status);
  }

  String? extractMegaUpUrlFromScript(String content) {
    final regex = RegExp(
      r'''\.html\(\s*["'].*?href=["']([^"']+)["']''',
      dotAll: true,
      caseSensitive: false,
    );

    final match = regex.firstMatch(content);
    return match?.group(1);
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    throw DownloadRequireManualException('Needs manual download for 1Fichier');
  }
}
