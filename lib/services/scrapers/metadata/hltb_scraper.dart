import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'package:html/dom.dart';
import 'package:yamata_launcher/models/hltb.dart';

class HltbScraper {
  static const String _baseUrl = 'https://howlongtobeat.com';
  static const String _searchUrl = '$_baseUrl/api/locate';
  static const String _detailUrl = '$_baseUrl/game?id=';
  static const String _imageUrl = '$_baseUrl/games/';
  String? _nextJsKey;
  static String currentUa = "";
  final List<String> _ua = [
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/37.0.2062.94 Chrome/37.0.2062.94 Safari/537.36"
        "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.85 Safari/537.36"
        "Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko"
        "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.0"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/600.8.9 (KHTML, like Gecko) Version/8.0.8 Safari/600.8.9"
        "Mozilla/5.0 (iPad; CPU OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12H321 Safari/600.1.4"
        "Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.85 Safari/537.36"
        "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.85 Safari/537.36"
  ];
  String? _authToken;
  DateTime? _authTokenFetchedAt;

  /// =========================
  /// PUBLIC API
  /// =========================

  Future<List<HltbEntry>> search(String query) async {
    if (_authToken == null) {
      await _refreshAuthToken();
    }

    final body = {
      "searchType": "games",
      "searchTerms": query.split(' '),
      "searchPage": 1,
      "size": 20,
      "searchOptions": {
        "games": {
          "userId": 0,
          "platform": "",
          "sortCategory": "name",
          "rangeCategory": "main",
          "rangeTime": {"min": 0, "max": 0},
          "gameplay": {
            "perspective": "",
            "flow": "",
            "genre": "",
            "difficulty": ""
          },
          "modifier": "hide_dlc"
        },
        "filter": "",
        "sort": 0,
        "randomizer": 0
      }
    };

    Future<http.Response> doSearch() {
      return http.post(
        Uri.parse('$_baseUrl/api/search'),
        headers: {
          'User-Agent': currentUa,
          'Content-Type': 'application/json',
          'Origin': _baseUrl,
          'Referer': _baseUrl,
          'x-auth-token': _authToken!,
        },
        body: jsonEncode(body),
      );
    }

    var res = await doSearch();

    if (res.statusCode == 403) {
      await _refreshAuthToken();
      res = await doSearch();
    }

    if (res.statusCode != 200) {
      throw Exception('HLTB search failed: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final results = List<Map<String, dynamic>>.from(data['data']);

    final List<HltbEntry> entries = [];
    for (final item in results) {
      final gameId = item['game_id'];
      if (gameId is! int) continue;

      final gameData = await _fetchGameJson(gameId);
      if (gameData == null) continue;

      entries.add(
        HltbEntry(
          id: gameId.toString(),
          name: gameData['game_name'] ?? item['game_name'],
          description: '',
          platforms: (gameData['profile_platform'] ?? '')
              .toString()
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
          imageUrl: '$_imageUrl${item['game_image']}',
          gameplayMain: ((gameData['comp_main'] ?? 0) / 3600).round(),
          gameplayMainExtra: ((gameData['comp_plus'] ?? 0) / 3600).round(),
          gameplayCompletionist: ((gameData['comp_100'] ?? 0) / 3600).round(),
          similarity: 1.0,
          searchTerm: query,
        ),
      );
    }
    return entries;
  }

  Future<HltbEntry> detail(String gameId) async {
    final gameIdInt = int.tryParse(gameId);
    if (gameIdInt == null) {
      throw Exception('Invalid HLTB gameId: $gameId');
    }

    final gameData = await _fetchGameJson(gameIdInt);
    if (gameData == null) {
      throw Exception('Failed to fetch game JSON for $gameId');
    }
    final name = gameData['game_name'] ?? '';
    final description = gameData['profile_summary'] ?? '';

    final platforms = (gameData['profile_platform'] ?? '')
        .toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final image = gameData['game_image'] != null
        ? '$_imageUrl${gameData['game_image']}'
        : '';

    return HltbEntry(
      id: gameId,
      name: name,
      description: description,
      platforms: platforms,
      imageUrl: image,
      gameplayMain: ((gameData['comp_main'] ?? 0) / 3600).round(),
      gameplayMainExtra: ((gameData['comp_plus'] ?? 0) / 3600).round(),
      gameplayCompletionist: ((gameData['comp_100'] ?? 0) / 3600).round(),
      similarity: 1.0,
      searchTerm: name,
    );
  }

  Future<String> _getNextJsKey() async {
    if (_nextJsKey != null) return _nextJsKey!;

    final res = await http.get(
      Uri.parse(_baseUrl),
      headers: {
        'User-Agent': currentUa,
        'Origin': _baseUrl,
        'Referer': _baseUrl,
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load HLTB homepage');
    }

    final doc = parse(res.body);
    final scripts = doc.querySelectorAll('script[src]');

    for (final script in scripts) {
      final src = script.attributes['src'];
      if (src == null) continue;

      if (src.contains('_ssgManifest') || src.contains('_buildManifest')) {
        final match = RegExp(r'/_next/static/(.+?)/').firstMatch(src);
        if (match != null) {
          _nextJsKey = match.group(1)!;
          return _nextJsKey!;
        }
      }
    }

    throw Exception('Could not find Next.js key');
  }

  Future<Map<String, dynamic>?> _fetchGameJson(int gameId) async {
    final key = await _getNextJsKey();

    final res = await http.get(
      Uri.parse('$_baseUrl/_next/data/$key/game/$gameId.json'),
      headers: {
        'User-Agent': currentUa,
        'Origin': _baseUrl,
        'Referer': _baseUrl,
      },
    );

    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    final list = data?['pageProps']?['game']?['data']?['game'];

    if (list is List && list.length == 1) {
      return Map<String, dynamic>.from(list[0]);
    }

    return null;
  }

  Future<void> _refreshAuthToken() async {
    currentUa = _ua[Random.secure().nextInt(_ua.length)];
    final res = await http.get(
      Uri.parse(
          '$_baseUrl/api/search/init?t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: {
        'User-Agent': currentUa,
        'Referer': _baseUrl,
        'Origin': _baseUrl,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to init auth token');
    }
    final data = jsonDecode(res.body);
    _authToken = data['token'];
    _authTokenFetchedAt = DateTime.now();
  }

  Map<String, String> _headers() => {
        'User-Agent': _ua[Random.secure().nextInt(_ua.length)],
        'Content-Type': 'application/json',
        'Origin': _baseUrl,
        'Referer': _baseUrl,
        'x-auth-token':
            "MTQ4LjEwMS40OC4yMzR8MTc2NjI2NzI4ODYwMy40YzU3Mjc0N2M1NWU0MDk4ZWYwYjViMTM5NDA2ZTU3YjU2NGQ3MzMwZTA2NDg0YzcxMzQxNmMwZGI1NTM1Mzcw",
        'Cookie':
            "OTGPPConsent=DBABLA~BVQqAAAAAAKA.QA; usprivacy=1YNY; OptanonConsent=isGpcEnabled=0&datestamp=Sat+Dec+20+2025+17%3A17%3A34+GMT-0400+(hora+de+Venezuela)&version=202509.1.0&browserGpcFlag=0&isIABGlobal=false&genVendors=&consentId=56ec003a-f772-448b-853a-6a6f381db4b7&interactionCount=0&isAnonUser=1&landingPath=NotLandingPage&GPPCookiesCount=1&gppSid=7&groups=C0001%3A1%2CC0002%3A1%2COSSTA_BG%3A1%2CC0004%3A1&AwaitingReconsent=false"
      };

  Map<String, dynamic> _basePayload() => {
        "searchType": "games",
        "searchTerms": [],
        "searchPage": 1,
        "size": 20,
        "searchOptions": {
          "games": {
            "userId": 0,
            "platform": "",
            "sortCategory": "popular",
            "rangeCategory": "main",
            "rangeTime": {"min": 0, "max": 0},
            "gameplay": {"perspective": "", "flow": "", "genre": ""},
            "modifier": ""
          }
        }
      };

  List<String> _parsePlatforms(Document doc) {
    for (final el
        in doc.querySelectorAll('div[class*=GameSummary_profile_info__]')) {
      final text = el.text;
      if (text.contains('Platforms:')) {
        return text
            .replaceAll('\n', '')
            .replaceAll('Platforms:', '')
            .split(',')
            .map((e) => e.trim())
            .toList();
      }
    }
    return [];
  }

  Map<String, int> _parseTimes(Document doc) {
    int main = 0, extra = 0, complete = 0;

    final items = doc.querySelectorAll('div[class*=GameStats_game_times__] li');

    for (final li in items) {
      final type = li.querySelector('h4')?.text ?? '';
      final timeText = li.querySelector('h5')?.text ?? '';
      final time = _parseTime(timeText);

      if (type.startsWith('Main')) main = time;
      if (type.startsWith('Main +')) extra = time;
      if (type.startsWith('Completionist')) complete = time;
    }

    return {
      'main': main,
      'extra': extra,
      'complete': complete,
    };
  }

  int _parseTime(String text) {
    if (text.startsWith('--')) return 0;

    if (text.contains(' - ')) {
      final parts = text.split(' - ');
      return ((_parseTime(parts[0]) + _parseTime(parts[1])) / 2).round();
    }

    if (text.contains('Mins')) return 1;

    if (text.contains('½')) {
      final base = int.tryParse(text.split('½')[0]) ?? 0;
      return base + 1;
    }

    return int.tryParse(text.split(' ').first) ?? 0;
  }
}
