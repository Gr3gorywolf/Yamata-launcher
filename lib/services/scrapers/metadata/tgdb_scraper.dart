import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'package:html/dom.dart';
import 'package:yamata_launcher/models/tgdb.dart';
import 'package:yamata_launcher/services/scrapers/metadata/constants/tgdb_consoles_mapping.dart';

class TheGamesDbScraper {
  static const String _baseUrl = 'https://thegamesdb.net';

  /// =========================
  /// SEARCH
  /// =========================

  Future<List<TgdbSearchResult>> search(String query, String? platform) async {
    var foundPlatformId = TGDB_CONSOLES_MAPPING[platform ?? ''];
    var platformQuery = "";
    if (foundPlatformId != null) {
      platformQuery += '&platform_id%5B%5D=$foundPlatformId';
    }
    final url = Uri.parse(
        '$_baseUrl/search.php?name=${Uri.encodeQueryComponent(query)}$platformQuery');

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Search failed: ${res.statusCode}');
    }

    final doc = parse(res.body);
    final results = <TgdbSearchResult>[];

    final cards = doc.querySelectorAll('#display .col-6');

    for (final card in cards) {
      final link = card.querySelector('a');
      final href = link?.attributes['href'];
      if (href == null || !href.contains('game.php?id=')) continue;

      final id = int.parse(href.split('id=').last);

      final img = card.querySelector('img.card-img-top');
      final thumbnail = img?.attributes['src'] ?? '';
      final title = img?.attributes['alt']?.replaceAll(' cover', '') ?? '';

      final footerTexts = card
          .querySelectorAll('.card-footer p')
          .map((e) => e.text.trim())
          .toList();

      String region = '';
      String releaseDate = '';
      String platform = '';

      for (final text in footerTexts) {
        if (text.contains('NTSC') || text.contains('PAL')) {
          region = text.replaceAll(RegExp(r'\s+'), ' ');
        } else if (RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(text)) {
          releaseDate = text;
        } else if (text.isNotEmpty && !text.contains(title)) {
          platform = text;
        }
      }

      results.add(
        TgdbSearchResult(
          id: id,
          title: title,
          platform: platform,
          region: region,
          releaseDate: releaseDate,
          thumbnail: thumbnail,
          detailUrl: '$_baseUrl/game.php?id=$id',
        ),
      );
    }

    return results;
  }

  /// =========================
  /// DETAIL
  /// =========================

  Future<TgdbGameDetail> detail(int gameId) async {
    final url = Uri.parse('$_baseUrl/game.php?id=$gameId');

    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Detail failed: ${res.statusCode}');
    }

    final doc = parse(res.body);

    // Title
    final title = doc.querySelector('.card-header h1')?.text.trim() ?? '';

    // Description
    final description = doc.querySelector('.game-overview')?.text.trim() ?? '';

    final List<String> titleScreens = [];
    final List<String> screenshots = [];

    final images = doc.querySelectorAll('img');

    for (final img in images) {
      final alt = img.attributes['alt']?.toLowerCase() ?? '';
      final src = img.attributes['src'] ?? '';

      if (src.isEmpty) continue;

      if (alt.contains('titlescreen(s)')) {
        titleScreens.add(src.replaceAll('cropped_center_thumb', 'original'));
      } else if (alt.contains('screenshot(s)')) {
        screenshots.add(src.replaceAll('cropped_center_thumb', 'original'));
      }
    }
    print({
      'title': title,
      'description': description,
      'titleScreens': titleScreens,
      'screenshots': screenshots,
    });
    return TgdbGameDetail(
      title: title,
      description: description,
      titleScreens: titleScreens,
      screenshots: screenshots,
    );
  }
}
