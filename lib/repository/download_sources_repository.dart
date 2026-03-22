import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/models/contracts/hoster.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/exceptions/download_require_manual_exception.dart';
import 'package:yamata_launcher/models/hoster_metadata.dart';
import 'package:yamata_launcher/services/cookies_service.dart';
import 'package:yamata_launcher/services/scrapers/hosters/buzzheavier_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/datanodes_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/fuckingfast_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/gofile_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/google_drive_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/krakenfiles_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/mediafire_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/mega_nz_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/megaup_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/pixeldrain_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/qiwi_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/rootz_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/send_cm_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';
import 'package:yamata_launcher/services/scrapers/hosters/vik1ngfile_hoster.dart';
import 'package:yamata_launcher/utils/http_helper.dart';
import 'package:yamata_launcher/utils/url_helper.dart';

class DownloadSourcesRepository {
  var _allHosters = [
    BuzzHeavierHoster(),
    DatanodesHoster(),
    FuckingFastHoster(),
    //TODO: correct this GofileHoster(),
    MediafireHoster(),
    PixelDrainHoster(),
    RootzHoster(),
    //TODO: correct this hoster MegaHoster(),
    // TODO: correct the manual flow for this QiwiHoster(),
    //TODO: correct the manual flow for this  SendCmHoster(),
    MegaupHoster(),
    KrakenfilesHoster(),
    GoogleDriveHoster(),
    Vik1ngfileHoster()
  ];
  static Map<String, bool> directDownloadUris = {};
  static Map<String, HosterMetadata> metadataCache = {};

  bool _isDownloadContentType(String? contentType) {
    if (contentType == null) return false;
    final ct = contentType.toLowerCase();

    return ct.startsWith('application/') &&
        !ct.contains('json') &&
        !ct.contains('xml') &&
        !ct.contains('html');
  }

  bool urlIsTorrent(String url) {
    return url.toLowerCase().endsWith('.torrent') ||
        url.toLowerCase().startsWith('magnet:');
  }

  bool _isDownloadable(Map<String, String> headers) {
    final contentDisposition = headers['content-disposition'];
    final contentType = headers['content-type'];

    final isAttachment = contentDisposition != null &&
        contentDisposition.toLowerCase().contains('attachment');

    final isDownloadType =
        contentType != null && _isDownloadContentType(contentType);

    return isDownloadType || isAttachment;
  }

  Future<bool> isDirectDownload(String url) async {
    if (directDownloadUris.containsKey(url)) {
      return directDownloadUris[url]!;
    }

    var siteCookies =
        await CookiesService().getSiteCookies(UrlHelper.getSiteFromUrl(url));
    var siteAditionalHeaders =
        HttpHelper().parseHeaders(siteCookies?.headers ?? "");
    final headers = {
      "User-Agent": CommonHosterUtils().hosterUserAgent,
      "Accept": "*/*",
      "Connection": "close",
      "Cookie": siteCookies?.cookie?.trim() ?? "",
      ...siteAditionalHeaders
    };

    final client = http.Client();
    // Try with head request
    try {
      final res = await http.head(Uri.parse(url)).timeout(Duration(seconds: 3))
        ..headers.addAll(headers);

      var isDownloadable = _isDownloadable(res.headers);
      if (isDownloadable) {
        directDownloadUris[url] = true;
        return true;
      }
    } catch (err) {}
    // try to get the actual content with a get request
    try {
      final streamed = await HttpHelper()
          .sendRequestWithRedirects(client, Uri.parse(url), headers,
              maxRedirects: 20)
          .timeout(const Duration(seconds: 10));

      final responseHeaders = streamed.headers;
      var isDownloadble = _isDownloadable(responseHeaders);
      print(streamed.statusCode);
      print(responseHeaders);
      directDownloadUris[url] = isDownloadble;
      return isDownloadble;
    } catch (e) {
      print("Header probe failed: $e");
      client.close();
    }

    directDownloadUris[url] = false;
    return false;
  }

  String getSourceTitle(dynamic responseData, DownloadSourceType type) {
    if (type == DownloadSourceType.Hydra) {
      return responseData['name'] ??
          "Unknown Hydra Source - ${responseData['downloads'].length} items";
    } else {
      return responseData['title'] ??
          responseData['sourceInfo']['title'] ??
          "Unknown - ${responseData['downloads'].length} items";
    }
  }

  Future<DownloadSourceWithDownloads?> fetchDownloadSource(
      String sourceUrl, DownloadSourceType type) async {
    var client = new http.Client();

    try {
      var res =
          await client.get(Uri.parse(sourceUrl)).timeout(Duration(seconds: 40));
      if (res.statusCode == 200) {
        var responseData = json.decode(res.body);

        List<DownloadSourceRom> downloads = (responseData['downloads'] as List)
            .where((download) =>
                download is Map<String, dynamic> &&
                download['title'] != null &&
                download['uris']?.isNotEmpty)
            .map((download) {
          if (type == DownloadSourceType.Hydra) {
            download['console'] = CONSOLE_SLUGS.windows.value;
          }
          return DownloadSourceRom.fromJson(download);
        }).toList();
        DateTime lastDownloadDate = downloads
            .map((e) => DateTime.tryParse(e.uploadDate!) ?? DateTime.now())
            .reduce((a, b) => a.isAfter(b) ? a : b);

        return DownloadSourceWithDownloads(
            sourceInfo: DownloadSource(
                title: getSourceTitle(responseData, type),
                passwords: (responseData['passwords'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList(),
                romsCount: downloads.length,
                lastUpdated: lastDownloadDate.toIso8601String()),
            downloads: downloads);
      } else
      // If its not available on hydralink uses a backup from powerindex
      if (type == DownloadSourceType.Hydra) {
        const backupUrl =
            "https://raw.githubusercontent.com/PowerIndex-x/yamata-launcher-links/refs/heads/main/public/data/hydra-links-mirror.json";
        var res = await client
            .get(Uri.parse(backupUrl))
            .timeout(Duration(seconds: 15));
        if (res.statusCode == 200) {
          var responseData = json.decode(res.body);
          var sourceBackupUrl = responseData[sourceUrl];
          if (sourceBackupUrl != null) {
            return await fetchDownloadSource(sourceBackupUrl, type);
          }
        }
        return null;
      }
    } catch (e) {
      print(e);
      return null;
    }
  }

  /**
   * Gets the third party hoster name for a given download source URL.
   */
  String? getDownloadSourceUrlHosterName(String url) {
    for (var hoster in _allHosters) {
      if (hoster.canHandleUrl(url)) {
        return hoster.name;
      }
    }
    if (urlIsTorrent(url)) {
      return "Torrent";
    }
    return null;
  }

  Hoster? getHosterForUrl(String url) {
    for (var hoster in _allHosters) {
      if (hoster.canHandleUrl(url)) {
        return hoster;
      }
    }
    return null;
  }

  /**
   * Extracts metadata (like file name, validity) for a given download source URL by checking against known hosters.
   */
  Future<HosterMetadata> extractHosterMetadata(String url) async {
    if (metadataCache.containsKey(url)) {
      print('[Metadata] Using cached metadata for $url');
      return metadataCache[url]!;
    }
    var invalidMetadata = HosterMetadata(status: HosterStatus.Invalid);
    print("Extracting hoster metadata for: $url");
    final hoster = getHosterForUrl(url);
    if (hoster == null) {
      return invalidMetadata;
    }
    try {
      var extractedMetadata = await hoster.extractMetadata(url);
      if (extractedMetadata == null) {
        return invalidMetadata;
      }
      metadataCache[url] = extractedMetadata;
      return extractedMetadata;
    } on Exception catch (e) {
      if (e is DownloadRequireManualException) {
        return HosterMetadata(status: HosterStatus.NeedsManual);
      }
      return invalidMetadata;
    }
  }

  /**
   * Extracts the direct download URL from a given source URL by checking against known hosters.
   */
  Future<String?> extractDirectDownloadUrl(String url) async {
    if (url.isEmpty) return null;
    print("Extracting direct download URL for: $url");
    if (urlIsTorrent(url)) {
      return url;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }

    for (var hoster in _allHosters) {
      if (hoster.canHandleUrl(url)) {
        try {
          final directUrl = await hoster.extractDownloadUrl(url);
          if (directUrl != null && directUrl.isNotEmpty) {
            return directUrl;
          }
        } on Exception catch (e) {
          print(
              'Error extracting direct download url for hoster ${hoster.name} with link $url: ${e.toString()}');
          if (e is DownloadRequireManualException) {
            throw e;
          }
          throw Exception(
              'Error extracting direct download url for hoster ${hoster.name}: ${e.toString()}');
        }
      }
    }
  }
}
