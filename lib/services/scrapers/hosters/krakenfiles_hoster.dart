import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/exceptions/download_require_manual_exception.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';

class KrakenfilesHoster implements Hoster {
  @override
  String get name => 'Krakenfiles';

  static const _domains = [
    'krakenfiles.com',
  ];

  @override
  bool canHandleUrl(String url) {
    return _domains.any((d) => url.toLowerCase().contains(d));
  }

  @override
  bool isValidDirectDownloadUrl(String url) {
    return url.contains("krakencloud.net/force-download");
  }

  @override
  Future<HosterMetadata?> extractMetadata(String url) async {
    var document = await CommonHosterUtils().fetchHtml(url);
    if (document == null) return HosterMetadata(status: HosterStatus.Invalid);
    var fileName = document.querySelector('title')?.text.trim();
    if (fileName == null ||
        fileName.isEmpty ||
        fileName.contains('File not found')) {
      return HosterMetadata(status: HosterStatus.Invalid);
    }
    return HosterMetadata(
        fileName: fileName.replaceAll(" - Krakenfiles.com", ""),
        status: HosterStatus.NeedsManual);
  }

  @override
  Future<String?> extractDownloadUrl(String url) async {
    if (CommonHosterUtils.directDownloadUris.containsKey(url)) {
      print('[Krakenfiles] Using cached direct link');
      return CommonHosterUtils.directDownloadUris[url];
    }
    throw DownloadRequireManualException(
        "This hoster doesn't support automatic download url extraction yet");
  }
}
