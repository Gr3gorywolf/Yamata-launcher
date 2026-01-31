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

  bool _isDownloadContentType(String? contentType) {
    if (contentType == null) return false;
    final ct = contentType.toLowerCase();

    return ct.startsWith('application/') &&
        !ct.contains('json') &&
        !ct.contains('xml') &&
        !ct.contains('html');
  }

  Future<String?> extractDownloadSourceUrl(DownloadSourceRom sourceRom) async {
    if (sourceRom.uris == null || sourceRom.uris!.isEmpty) {
      return null;
    }
    for (final rawUrl in sourceRom.uris!) {
      final url = rawUrl.trim();
      if (url.isEmpty) continue;

      if (url.toLowerCase().startsWith('magnet:?')) {
        return url;
      }

      final uri = Uri.tryParse(url);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        continue;
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

      try {
        final res = await http.head(uri);
        print(res.headers);
        final contentDisposition = res.headers['content-disposition'];
        final contentType = res.headers['content-type'];

        final isAttachment = contentDisposition != null &&
            contentDisposition.toLowerCase().contains('attachment');

        final isDownloadType =
            contentType != null && _isDownloadContentType(contentType);

        if (isAttachment || isDownloadType) {
          return url;
        }
      } catch (_) {}
    }

    return null;
  }
}
