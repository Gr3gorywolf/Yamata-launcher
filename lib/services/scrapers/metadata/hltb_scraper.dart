import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/hltb.dart';

class HltbScraper {
  static const String _baseUrl = 'https://howlongtobeat.com';
  static const String _imageUrl = '$_baseUrl/games/';
  static const String _searchEndpoint = '/api/find';

  String? _authToken;
  String? _hpKey;
  String? _hpVal;
  DateTime? _authTokenFetchedAt;

  static String currentUa =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:145.0) Gecko/20100101 Firefox/145.0";

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
      final payload = Map<String, dynamic>.from(body);
      final headers = <String, String>{
        ..._baseHeaders,
        if (_authToken?.isNotEmpty == true) 'x-auth-token': _authToken!,
        if (_hpKey?.isNotEmpty == true) 'x-hp-key': _hpKey!,
        if (_hpVal?.isNotEmpty == true) 'x-hp-val': _hpVal!,
      };

      if (_hpKey?.isNotEmpty == true && _hpVal?.isNotEmpty == true) {
        payload[_hpKey!] = _hpVal;
      }

      return http.post(
        Uri.parse('$_baseUrl$_searchEndpoint'),
        headers: headers,
        body: jsonEncode(payload),
      );
    }

    var res = await doSearch();

    if (res.statusCode == 401 || res.statusCode == 403) {
      await _refreshAuthToken();
      res = await doSearch();
    }

    if (res.statusCode != 200) {
      throw Exception('HLTB search failed: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final rawResults = data is Map<String, dynamic> ? data['data'] : null;
    final results = rawResults is List
        ? rawResults
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

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
          gameplayMain: _secondsToHours(item['comp_main']),
          gameplayMainExtra: _secondsToHours(item['comp_plus']),
          gameplayCompletionist: _secondsToHours(item['comp_100']),
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
      gameplayMain: _secondsToHours(gameData['comp_main']),
      gameplayMainExtra: _secondsToHours(gameData['comp_plus']),
      gameplayCompletionist: _secondsToHours(gameData['comp_100']),
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
          '$_baseUrl$_searchEndpoint/init?t=${DateTime.now().millisecondsSinceEpoch}'),
      headers: _baseHeaders,
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to init HLTB token');
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid HLTB token response');
    }

    _authToken = data['token']?.toString();
    _hpKey = data['hpKey']?.toString();
    _hpVal = data['hpVal']?.toString();
    _authTokenFetchedAt = DateTime.now();
  }

  Future<Map<String, dynamic>?> _fetchGameFromPage(int gameId) async {
    await Future.delayed(Duration(milliseconds: Random().nextInt(100)));

    final res = await http.get(
      Uri.parse('$_baseUrl/game?id=$gameId'),
      headers: _baseHeaders,
    );

    if (res.statusCode != 200) return null;

    try {
      final jsonText = _extractNextDataJson(res.body);
      if (jsonText == null || jsonText.isEmpty) return null;

      final jsonData = jsonDecode(jsonText);
      if (jsonData is! Map<String, dynamic>) return null;

      final game = jsonData['props']?['pageProps']?['game']?['data']?['game'];

      if (game is List && game.isNotEmpty) {
        return Map<String, dynamic>.from(game[0]);
      }
    } catch (_) {}

    return null;
  }

  int _secondsToHours(dynamic value) {
    final seconds =
        value is num ? value : num.tryParse(value?.toString() ?? '');
    if (seconds == null || seconds <= 0) return 0;
    return (seconds / 3600).round();
  }

  String? _extractNextDataJson(String html) {
    final match = RegExp(
      r'<script[^>]*id=["' ']__NEXT_DATA__["' '][^>]*>(.*?)<\/script>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    return match?.group(1);
  }
}
