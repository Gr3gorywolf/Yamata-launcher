import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:yamata_launcher/models/launchbox.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/services/scrapers/metadata/constants/launchbox_consoles_mapping.dart';

class LaunchboxScraper {
  final String baseUrl = "https://gamesdb.launchbox-app.com/";
  Future<List<RomInfo>> search(String query) async {
    final res = await http
        .get(Uri.parse("$baseUrl/games/results/${Uri.encodeComponent(query)}"));

    if (res.statusCode != 200) {
      return [];
    }

    final doc = html_parser.parse(res.body);
    List<RomInfo> results = [];
    var cards = doc.querySelectorAll("div.games-grid-card");
    var slugMap = LAUNCHBOX_CONSOLES_MAPPING.entries
        .fold<Map<String, String>>({}, (map, entry) {
      map[entry.value.toLowerCase()] = entry.key;
      return map;
    });
    print("Found ${cards.length} cards");
    for (var card in cards) {
      try {
        final aTag = card.querySelector('a.link-no-underline');
        final detailsUrl = aTag != null ? aTag.attributes['href'] : null;

        final nameTag = card.querySelector('.cardTitle h3');
        final name = nameTag != null ? nameTag.text.trim() : 'Unknown';
        final gameplayCovers = <String>[
          if (card.querySelector('.cardImgPart img') != null)
            card.querySelector('.cardImgPart img')!.attributes['src'] ?? ''
        ];
        final portrait =
            card.querySelector(".imgOver img")?.attributes['src'] ?? '';
        final rating = card.querySelector(".ratings-short h6")?.text.trim();
        final consoleTag = card.querySelector('.cardTitle p')?.text.trim();
        final consoleSlug = consoleTag != null
            ? slugMap[consoleTag.toLowerCase()] ?? 'unknown'
            : 'unknown';
        print("Parsed card: $name on $consoleSlug $consoleTag");
        if (consoleSlug == 'unknown') {
          continue;
        }

        results.add(RomInfo(
            slug: consoleSlug + "-" + RomService.normalizeRomTitle(name),
            detailsUrl: baseUrl + (detailsUrl ?? ''),
            name: name,
            console: consoleSlug,
            gameplayCovers:
                gameplayCovers.where((url) => url.isNotEmpty).toList(),
            rating: rating,
            portrait: portrait));
      } catch (_) {
        print("Error parsing card: $_");
        // Ignore individual parsing errors
      }
    }

    return results;
  }

  Future<LaunchboxRomDetails?> detail(String url) async {
    final res = await http.get(Uri.parse(url));

    if (res.statusCode != 200) {
      return null;
    }

    final doc = html_parser.parse(res.body);

    // ---------- DESCRIPTION (Overview) ----------
    String? description;
    try {
      final overviewArticle =
          doc.querySelector('section.game-details-content article');
      if (overviewArticle != null) {
        final paragraphs =
            overviewArticle.querySelectorAll('p.text-body-lg.text-dark-100');
        final descText = paragraphs
            .map((p) => p.text.trim())
            .where((t) => t.isNotEmpty)
            .join('\n\n');
        if (descText.isNotEmpty) {
          description = descText;
        }
      }
    } catch (_) {
      description = null;
    }

    // ---------- Details ----------
    String? maxPlayers;
    bool? cooperative;
    String? esrb;

    try {
      final detailRows = doc.querySelectorAll('aside dl > div');
      for (final row in detailRows) {
        final dt = row.querySelector('dt');
        final dd = row.querySelector('dd');
        if (dt == null || dd == null) continue;

        final label = dt.text.trim();
        final value = dd.text.trim();

        switch (label) {
          case 'Max Players':
            maxPlayers = value;
            break;
          case 'Cooperative':
            cooperative = value.toLowerCase().startsWith('y')
                ? true
                : value.toLowerCase().startsWith('n')
                    ? false
                    : null;
            break;
          case 'ESRB':
            esrb = value;
            break;
          default:
            break;
        }
      }
    } catch (_) {}

    // ---------- GENRES ----------
    List<String>? genres;
    try {
      final overviewArticle =
          doc.querySelector('section.game-details-content article');
      if (overviewArticle != null) {
        final dts = overviewArticle.querySelectorAll('dl dt');
        Element? genreDt;
        for (final dt in dts) {
          if (dt.text.trim() == 'Genre') {
            genreDt = dt;
            break;
          }
        }

        if (genreDt != null) {
          final parentDiv = genreDt.parent;
          final dd = parentDiv?.querySelector('dd');
          if (dd != null) {
            final genreLinks = dd.querySelectorAll('a');
            genres = genreLinks
                .map((a) => a.text.trim())
                .where((t) => t.isNotEmpty)
                .toList();
          }
        }
      }
    } catch (_) {
      genres = null;
    }

    String? video;
    try {
      final overviewArticle =
          doc.querySelector('section.game-details-content article');
      if (overviewArticle != null) {
        final dts = overviewArticle.querySelectorAll('dl dt');
        Element? videoDt;
        for (final dt in dts) {
          if (dt.text.trim() == 'Video') {
            videoDt = dt;
            break;
          }
        }

        if (videoDt != null) {
          final parentDiv = videoDt.parent; // <div> con dt y dd
          final dd = parentDiv?.querySelector('dd');
          final a = dd?.querySelector('a');
          video = a?.attributes['href'];
        }
      }
    } catch (_) {
      video = null;
    }

    List<String>? screenshots;
    try {
      final imgNodes = doc.querySelectorAll('img');
      final urls = <String>{};

      for (final img in imgNodes) {
        final alt = img.attributes['alt'] ?? '';
        if (alt.contains('Screenshot')) {
          final src = img.attributes['src'] ?? '';
          if (src.isNotEmpty) {
            urls.add(src);
          }
        }
      }

      if (urls.isNotEmpty) {
        screenshots = urls.toList();
      }
    } catch (_) {
      screenshots = null;
    }

    return LaunchboxRomDetails(
      description: description,
      maxPlayers: maxPlayers,
      cooperative: cooperative,
      esrb: esrb,
      genres: genres,
      video: video,
      screenshots: screenshots,
    );
  }
}
