import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'package:yamata_launcher/models/hltb.dart';

class HltbScraper {
  static const String _baseUrl = 'https://howlongtobeat.com';
  static const String _imageUrl = '$_baseUrl/games/';

  String? _authToken;
  DateTime? _authTokenFetchedAt;

  static String currentUa = "";

  final List<String> _ua = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"
  ];

  Map<String, String> get _baseHeaders => {
        'User-Agent': currentUa,
        'Referer': _baseUrl,
        'Origin': _baseUrl,
        'Content-Type': 'application/json',
      };

  /// =========================
  /// PUBLIC API
  /// =========================

  Future<List<HltbEntry>> search(String query) async {
    await _ensureToken();

    final body = {
      "searchType": "games",
      "searchTerms": query.split(' '),
      "searchPage": 1,
      "size": 20,
      "searchOptions": {
        "games": {
          "userId": 0,
          "platform": "",
          "sortCategory": "popular",
          "rangeCategory": "main",
          "rangeTime": {"min": null, "max": null},
          "gameplay": {
            "perspective": "",
            "flow": "",
            "genre": "",
            "difficulty": ""
          },
          "modifier": ""
        },
        "filter": "",
        "sort": 0,
        "randomizer": 0
      },
      "useCache": true
    };

    Future<http.Response> doSearch() {
      return http.post(
        Uri.parse('$_baseUrl/api/finder'),
        headers: {
          ..._baseHeaders,
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
      if (gameId == null) continue;

      entries.add(
        HltbEntry(
          id: gameId.toString(),
          name: item['game_name'] ?? '',
          description: '',
          platforms: [],
          imageUrl: '$_imageUrl${item['game_image']}',
          gameplayMain: ((item['comp_main'] ?? 0) / 3600).round(),
          gameplayMainExtra: ((item['comp_plus'] ?? 0) / 3600).round(),
          gameplayCompletionist: ((item['comp_100'] ?? 0) / 3600).round(),
          similarity: 1.0,
          searchTerm: query,
        ),
      );
    }

    return entries;
  }

  Future<HltbEntry> detail(String gameId) async {
    final id = int.tryParse(gameId);
    if (id == null) {
      throw Exception('Invalid HLTB gameId: $gameId');
    }

    final gameData = await _fetchGameFromPage(id);
    if (gameData == null) {
      throw Exception('Failed to fetch game detail');
    }

    final platforms = (gameData['profile_platform'] ?? '')
        .toString()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return HltbEntry(
      id: gameId,
      name: gameData['game_name'] ?? '',
      description: gameData['profile_summary'] ?? '',
      platforms: platforms,
      imageUrl: gameData['game_image'] != null
          ? '$_imageUrl${gameData['game_image']}'
          : '',
      gameplayMain: ((gameData['comp_main'] ?? 0) / 3600).round(),
      gameplayMainExtra: ((gameData['comp_plus'] ?? 0) / 3600).round(),
      gameplayCompletionist: ((gameData['comp_100'] ?? 0) / 3600).round(),
      similarity: 1.0,
      searchTerm: gameData['game_name'] ?? '',
    );
  }

  /// =========================
  /// INTERNAL
  /// =========================

  Future<void> _ensureToken() async {
    if (_authToken == null ||
        _authTokenFetchedAt == null ||
        DateTime.now().difference(_authTokenFetchedAt!) >
            const Duration(minutes: 30)) {
      await _refreshAuthToken();
    }
  }

  Future<void> _refreshAuthToken() async {
    currentUa = _ua[Random.secure().nextInt(_ua.length)];

    final res = await http.get(
      Uri.parse(
          '$_baseUrl/api/finder/init?t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: _baseHeaders,
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to init HLTB token');
    }

    final data = jsonDecode(res.body);
    _authToken = data['token'];
    _authTokenFetchedAt = DateTime.now();
  }

  /// Extrae datos desde __NEXT_DATA__ (igual que el script JS)
  Future<Map<String, dynamic>?> _fetchGameFromPage(int gameId) async {
    await Future.delayed(Duration(milliseconds: Random().nextInt(100)));

    final res = await http.get(
      Uri.parse('$_baseUrl/game/$gameId'),
      headers: _baseHeaders,
    );

    if (res.statusCode != 200) return null;

    final doc = parse(res.body);
    final script = doc.getElementById('__NEXT_DATA__');

    if (script == null) return null;

    try {
      final jsonData = jsonDecode(script.text);
      final game = jsonData?['props']?['pageProps']?['game']?['data']?['game'];

      if (game is List && game.isNotEmpty) {
        return Map<String, dynamic>.from(game[0]);
      }
    } catch (_) {}

    return null;
  }
}
