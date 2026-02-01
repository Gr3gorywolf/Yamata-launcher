import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/constants/console_constants.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/services/scrapers/hosters/buzzheavier_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/datanodes_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/fuckingfast_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/gofile_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/mediafire_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/pixeldrain_hoster.dart';
import 'package:yamata_launcher/services/scrapers/hosters/rootz_hoster.dart';
import 'package:yamata_launcher/ui/pages/settings/download_sources/download_sources_page.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class DownloadSourcesRepository {
  var _allHosters = [
    BuzzHeavierHoster(),
    DatanodesHoster(),
    FuckingFastHoster(),
    GofileHoster(),
    MediafireHoster(),
    PixelDrainHoster(),
    RootzHoster(),
  ];
  static Map<String, bool> directDownloadUris = {};

  bool _isDownloadContentType(String? contentType) {
    if (contentType == null) return false;
    final ct = contentType.toLowerCase();

    return ct.startsWith('application/') &&
        !ct.contains('json') &&
        !ct.contains('xml') &&
        !ct.contains('html');
  }

  bool _isUrlTorrent(String url) {
    return url.toLowerCase().endsWith('.torrent') ||
        url.toLowerCase().startsWith('magnet:');
  }

  Future<bool> isDirectDownload(String url) async {
    if (directDownloadUris.containsKey(url)) {
      return directDownloadUris[url]!;
    }
    try {
      final res = await http.head(Uri.parse(url)).timeout(Duration(seconds: 3));
      final contentDisposition = res.headers['content-disposition'];
      final contentType = res.headers['content-type'];

      final isAttachment = contentDisposition != null &&
          contentDisposition.toLowerCase().contains('attachment');

      final isDownloadType =
          contentType != null && _isDownloadContentType(contentType);

      if (isAttachment || isDownloadType) {
        directDownloadUris[url] = true;
        return true;
      }
    } catch (_) {}
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
          await client.get(Uri.parse(sourceUrl)).timeout(Duration(minutes: 15));
      if (res.statusCode == 200) {
        var responseData = json.decode(res.body);

        List<DownloadSourceRom> downloads =
            (responseData['downloads'] as List).map((download) {
          if (type == DownloadSourceType.Hydra) {
            download['console'] = "windows";
          }
          return DownloadSourceRom.fromJson(download);
        }).toList();
        DateTime lastDownloadDate = downloads
            .map((e) => DateTime.parse(e.uploadDate!))
            .reduce((a, b) => a.isAfter(b) ? a : b);

        return DownloadSourceWithDownloads(
            sourceInfo: DownloadSource(
                title: getSourceTitle(responseData, type),
                romsCount: downloads.length,
                lastUpdated: lastDownloadDate.toIso8601String()),
            downloads: downloads);
      } else {
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
    if (_isUrlTorrent(url)) {
      return "Torrent";
    }
    return null;
  }

  /**
   * Extracts the direct download URL from a given source URL by checking against known hosters.
   */
  Future<String?> extractDirectDownloadUrl(String url) async {
    if (url.isEmpty) return null;

    if (_isUrlTorrent(url)) {
      return url;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }

    try {
      for (var hoster in _allHosters) {
        if (hoster.canHandleUrl(url)) {
          final directUrl = await hoster.extractDownloadUrl(url);
          if (directUrl != null && directUrl.isNotEmpty) {
            return directUrl;
          }
        }
      }
    } catch (_) {
      print(
          '[DownloadSourcesRepository] Error processing hoster for url: $url ${_.toString()}');
    }
  }
}
