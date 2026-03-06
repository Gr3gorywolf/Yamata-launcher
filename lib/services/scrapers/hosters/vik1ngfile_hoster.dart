import 'dart:async';
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/exceptions/download_require_manual_exception.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class Vik1ngfileHoster implements Hoster {
  @override
  String get name => 'Vik1ngfile';

  static const _domains = ['vik1ngfile.site', 'vikingf1le.us.to'];

  @override
  bool canHandleUrl(String url) {
    final lower = url.toLowerCase();
    return _domains.any(lower.contains);
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    var matches = [
      "dl.vikingfile.com",
      "iw.vikingfile.com/download",
      "vikingfile.com/d/",
    ];
    return matches.any(url.contains);
  }

  @override
  Future<HosterMetadata?> extractMetadata(String url) async {
    var document = await CommonHosterUtils().fetchHtml(url);
    if (document == null) return HosterMetadata(status: HosterStatus.Invalid);
    var fileName = document.querySelector('#filename')?.text.trim();
    var status = HosterStatus.NeedsManual;
    if (fileName == null || fileName.isEmpty || fileName == 'File not found') {
      status = HosterStatus.Invalid;
    }
    return HosterMetadata(fileName: fileName, status: status);
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (!canHandleUrl(url)) return null;
    throw DownloadRequireManualException(
        'Vik1ngfile requires manual interaction');
  }
}
