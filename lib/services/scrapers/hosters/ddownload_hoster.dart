import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/exceptions/download_require_manual_exception.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class DdownloadHoster implements Hoster {
  @override
  String get name => 'Ddownload';

  static const _domains = ['ddownload.com'];

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _domains.any(lower.contains);
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    return url.contains(".dstorage.to:183/d");
  }

  @override
  Future<HosterMetadata?> extractMetadata(String url) async {
    var document = await CommonHosterUtils().fetchHtml(url);
    if (document == null) return HosterMetadata(status: HosterStatus.Invalid);
    var fileName = document
        .querySelector(
            '#container > div.dl-free-wrapper > form > div > div.dl-file-name')
        ?.text
        .trim();
    var status = HosterStatus.NeedsManual;
    if (fileName == null || fileName.isEmpty) {
      status = HosterStatus.Invalid;
    }
    return HosterMetadata(fileName: fileName, status: status);
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    throw DownloadRequireManualException('Needs manual download for Ddownload');
  }
}
