import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/hltb.dart';
import 'package:yamata_launcher/services/cache_service.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class HltbScraper {
  static const String _baseUrl = 'https://howlongtobeat.com';
  static const String _imageUrl = '$_baseUrl/games/';
  static const String _defaultSearchUrl = '/api/bleed';
  static const String _bootstrapCacheKey = 'hltb/bootstrap.json';
  static const String _userAgent =
      'Chrome: Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 '
      'Safari/537.36';

  static String _searchUrl = '';
  static _SearchAuth? _searchAuth;
  static String? _nextJsKey;
  static bool _bootstrapCacheLoaded = false;

  Map<String, String> get _baseHeaders => {
        'Content-Type': 'application/json',
        'Origin': _baseUrl,
        'Referer': '$_baseUrl/',
        'User-Agent': _userAgent,
      };

  Future<List<HltbEntry>> search(String query) async {
    final response = await _fetchWithSearchAuth(
      (auth) => _fetchSearchResultsWithAuth(query, auth),
    );

    if (response == null) {
      throw Exception('HLTB search failed');
    }

    if (response.statusCode != 200) {
      throw Exception('HLTB search failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final rawResults = decoded is Map<String, dynamic> ? decoded['data'] : null;
    if (rawResults is! List) {
      throw Exception('HLTB search returned invalid data');
    }

    final results = rawResults
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
            item['game_id'] is num &&
            item['game_name'] is String &&
            item['comp_all_count'] is num)
        .toList();

    final rankedResults = _rankResults(query, results);

    return rankedResults
        .map((ranked) => HltbEntry(
              id: ranked.gameId.toString(),
              name: ranked.name,
              description: '',
              platforms: _parsePlatforms(ranked.item['profile_platform']),
              imageUrl: _buildImageUrl(ranked.item['game_image']),
              gameplayMain: _secondsToHours(ranked.item['comp_main']),
              gameplayMainExtra: _secondsToHours(ranked.item['comp_plus']),
              gameplayCompletionist: _secondsToHours(ranked.item['comp_100']),
              similarity: ranked.similarity,
              searchTerm: query,
            ))
        .toList();
  }

  Future<HltbEntry> detail(String gameId) async {
    final id = int.tryParse(gameId);
    if (id == null) {
      throw Exception('Invalid HLTB gameId: $gameId');
    }

    final gameData = await _fetchGameData(id);
    if (gameData == null) {
      throw Exception('Failed to fetch game detail');
    }

    return HltbEntry(
      id: gameId,
      name: (gameData['game_name'] ?? '').toString(),
      description: (gameData['profile_summary'] ?? '').toString(),
      platforms: _parsePlatforms(gameData['profile_platform']),
      imageUrl: _buildImageUrl(gameData['game_image']),
      gameplayMain: _secondsToHours(gameData['comp_main']),
      gameplayMainExtra: _secondsToHours(gameData['comp_plus']),
      gameplayCompletionist: _secondsToHours(gameData['comp_100']),
      similarity: 1.0,
      searchTerm: (gameData['game_name'] ?? '').toString(),
    );
  }

  Future<void> _ensureBootstrapCacheLoaded() async {
    if (_bootstrapCacheLoaded) {
      return;
    }

    _bootstrapCacheLoaded = true;

    try {
      final cached = await CacheService.retrieveCacheFile(_bootstrapCacheKey);
      if (cached == null || cached.isEmpty) {
        _searchUrl = _defaultSearchUrl;
        return;
      }

      final decoded = jsonDecode(cached);
      if (decoded is! Map<String, dynamic>) {
        _searchUrl = _defaultSearchUrl;
        return;
      }

      final cachedSearchUrl = decoded['searchUrl'];
      _searchUrl = cachedSearchUrl is String && cachedSearchUrl.isNotEmpty
          ? cachedSearchUrl
          : _defaultSearchUrl;

      final cachedAuth = decoded['searchAuth'];
      if (cachedAuth is Map<String, dynamic>) {
        final token = cachedAuth['token'];
        final hpKey = cachedAuth['hpKey'];
        final hpVal = cachedAuth['hpVal'];

        if (token is String && hpKey is String && hpVal is String) {
          _searchAuth = _SearchAuth(
            token: token,
            hpKey: hpKey,
            hpVal: hpVal,
          );
        }
      }

      final cachedNextJsKey = decoded['nextJsKey'];
      if (cachedNextJsKey is String && cachedNextJsKey.isNotEmpty) {
        _nextJsKey = cachedNextJsKey;
      }
    } catch (_) {
      _searchUrl = _defaultSearchUrl;
    }
  }

  Future<void> _persistBootstrapCache() async {
    final payload = {
      'searchUrl': _searchUrl,
      'searchAuth': _searchAuth == null
          ? null
          : {
              'token': _searchAuth!.token,
              'hpKey': _searchAuth!.hpKey,
              'hpVal': _searchAuth!.hpVal,
            },
      'nextJsKey': _nextJsKey,
    };

    await CacheService.writeCacheFile(
      _bootstrapCacheKey,
      jsonEncode(payload),
    );
  }

  Future<void> _invalidateSearchAuth() async {
    _searchAuth = null;
    await _persistBootstrapCache();
  }

  Future<void> _invalidateNextJsKey() async {
    _nextJsKey = null;
    await _persistBootstrapCache();
  }

  Future<void> _persistSearchBootstrap(
    String currentSearchUrl,
    _SearchAuth auth,
  ) async {
    _searchUrl = currentSearchUrl;
    _searchAuth = auth;
    await _persistBootstrapCache();
  }

  Future<void> _persistNextJsKey(String nextJsKey) async {
    _nextJsKey = nextJsKey;
    await _persistBootstrapCache();
  }

  Map<String, String> _getSearchHeaders(_SearchAuth auth) {
    return {
      ..._baseHeaders,
      'Authority': 'howlongtobeat.com',
      'x-auth-token': auth.token,
      'x-hp-key': auth.hpKey,
      'x-hp-val': auth.hpVal,
    };
  }

  _SearchAuth? _parseSearchAuth(dynamic data) {
    if (data is! Map<String, dynamic>) {
      return null;
    }

    final token = data['token'];
    if (token is! String || token.isEmpty) {
      return null;
    }

    String? hpKey;
    String? hpVal;

    for (final entry in data.entries) {
      final value = entry.value;
      if (value is! String || value.isEmpty) {
        continue;
      }

      final fieldName = entry.key.toLowerCase();
      if (hpKey == null && fieldName.contains('key')) {
        hpKey = value;
      } else if (hpVal == null && fieldName.contains('val')) {
        hpVal = value;
      }
    }

    if (hpKey == null || hpVal == null) {
      return null;
    }

    return _SearchAuth(
      token: token,
      hpKey: hpKey,
      hpVal: hpVal,
    );
  }

  Future<_SearchAuth?> _fetchSearchAuth(String currentSearchUrl) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(
        Uri.parse('$_baseUrl$currentSearchUrl/init?t=$timestamp'),
        headers: _baseHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final auth = _parseSearchAuth(data);
        if (auth != null) {
          await _persistSearchBootstrap(currentSearchUrl, auth);
        }
        return auth;
      }
    } catch (_) {}

    await _invalidateSearchAuth();
    return null;
  }

  Future<String?> _fetchSearchUrl() async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: _baseHeaders,
      );

      if (response.statusCode != 200) {
        return null;
      }

      final scriptUrls = _extractScriptUrls(response.body, _baseUrl);

      for (final scriptUrl in scriptUrls) {
        final uri = Uri.parse(scriptUrl);
        if (uri.origin != _baseUrl || !uri.path.endsWith('.js')) {
          continue;
        }

        final scriptResponse = await http.get(
          uri,
          headers: _baseHeaders,
        );

        if (scriptResponse.statusCode != 200) {
          continue;
        }

        final discoveredSearchUrl =
            _extractSearchUrlFromScript(scriptResponse.body);
        if (discoveredSearchUrl != null) {
          return discoveredSearchUrl;
        }
      }

      return _defaultSearchUrl;
    } catch (_) {
      return null;
    }
  }

  List<String> _extractScriptUrls(String html, String baseUrl) {
    final scripts = <String>[];
    final pattern = RegExp(
      r'''<script\b[^>]*\bsrc=(["'])(.*?)\1[^>]*>''',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(html)) {
      final src = match.group(2);
      if (src == null || src.isEmpty) {
        continue;
      }

      scripts.add(Uri.parse(baseUrl).resolve(src).toString());
    }

    return scripts;
  }

  String? _extractSearchUrlFromScript(String scriptText) {
    if (!scriptText.contains('searchTerms') ||
        !scriptText.contains('searchOptions')) {
      return null;
    }

    final pattern = RegExp(
      r'''fetch\s*\(\s*["'`]\/api\/([a-zA-Z0-9_\/]+)[^"'`]*["'`]\s*,\s*{[^}]*method:\s*["'`]POST["'`][^}]*}''',
      caseSensitive: false,
      dotAll: true,
    );

    String? firstCandidate;

    for (final match in pattern.allMatches(scriptText)) {
      final pathSuffix = match.group(1);
      if (pathSuffix == null || pathSuffix.isEmpty) {
        continue;
      }

      final basePath =
          pathSuffix.contains('/') ? pathSuffix.split('/').first : pathSuffix;
      final discoveredSearchUrl = '/api/$basePath';
      firstCandidate ??= discoveredSearchUrl;

      final initPattern = RegExp(
        '\\/api\\/${RegExp.escape(basePath)}\\/init',
        caseSensitive: false,
      );

      if (initPattern.hasMatch(scriptText)) {
        return discoveredSearchUrl;
      }
    }

    return firstCandidate;
  }

  Future<String?> _fetchNextJsKey() async {
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: _baseHeaders,
      );

      if (response.statusCode != 200) {
        return null;
      }

      final pattern = RegExp(
        r'''/_next/static/([^"']+?)/(?:_ssgManifest|_buildManifest)\.js''',
        caseSensitive: false,
      );

      final match = pattern.firstMatch(response.body);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  Future<_SearchAuth?> _refreshSearchAuth(
      [bool refreshSearchPath = false]) async {
    await _ensureBootstrapCacheLoaded();

    if (refreshSearchPath || _searchUrl.isEmpty) {
      _searchUrl = (await _fetchSearchUrl()) ?? _defaultSearchUrl;
      await _invalidateSearchAuth();
    }

    if (_searchUrl.isEmpty) {
      _searchUrl = _defaultSearchUrl;
    }

    final auth = await _fetchSearchAuth(_searchUrl);
    if (auth != null || refreshSearchPath) {
      return auth;
    }

    await _invalidateSearchAuth();
    _searchUrl = (await _fetchSearchUrl()) ?? _defaultSearchUrl;
    return _fetchSearchAuth(_searchUrl);
  }

  Future<http.Response?> _fetchWithSearchAuth(
    Future<http.Response> Function(_SearchAuth auth) callback,
  ) async {
    await _ensureBootstrapCacheLoaded();

    var auth = _searchAuth ?? await _refreshSearchAuth();
    if (auth == null) {
      return null;
    }

    var response = await callback(auth);
    if (response.statusCode == 200) {
      return response;
    }

    await _invalidateSearchAuth();
    auth = await _refreshSearchAuth();
    if (auth != null) {
      response = await callback(auth);
      if (response.statusCode == 200) {
        return response;
      }
    }

    await _invalidateSearchAuth();
    auth = await _refreshSearchAuth(true);
    if (auth == null) {
      return null;
    }

    return callback(auth);
  }

  Future<http.Response> _fetchSearchResultsWithAuth(
    String gameName,
    _SearchAuth auth,
  ) {
    final data = {
      'searchType': 'games',
      'searchTerms': gameName.split(' '),
      'searchPage': 1,
      'size': 20,
      'searchOptions': {
        'games': {
          'userId': 0,
          'platform': '',
          'sortCategory': 'name',
          'rangeCategory': 'main',
          'rangeTime': {'min': 0, 'max': 0},
          'gameplay': {
            'perspective': '',
            'flow': '',
            'genre': '',
            'difficulty': '',
          },
          'modifier': 'hide_dlc',
        },
        'users': {},
        'filter': '',
        'sort': 0,
        'randomizer': 0,
      },
      auth.hpKey: auth.hpVal,
    };

    return http.post(
      Uri.parse('$_baseUrl$_searchUrl'),
      headers: _getSearchHeaders(auth),
      body: jsonEncode(data),
    );
  }

  Future<http.Response?> _fetchWithNextJsKey(
    Future<http.Response> Function(String key) callback,
  ) async {
    await _ensureBootstrapCacheLoaded();

    var key = _nextJsKey ?? await _fetchNextJsKey();
    if (key == null || key.isEmpty) {
      return null;
    }

    if (_nextJsKey != key) {
      await _persistNextJsKey(key);
    }

    var response = await callback(key);
    if (response.statusCode == 200) {
      return response;
    }

    await _invalidateNextJsKey();
    key = await _fetchNextJsKey();
    if (key == null || key.isEmpty) {
      return null;
    }

    await _persistNextJsKey(key);
    response = await callback(key);
    return response;
  }

  Future<Map<String, dynamic>?> _fetchGameData(int gameId) async {
    final response = await _fetchWithNextJsKey((key) {
      return http.get(
        Uri.parse('$_baseUrl/_next/data/$key/game/$gameId.json'),
      );
    });

    if (response == null || response.statusCode != 200) {
      return null;
    }

    try {
      final results = jsonDecode(response.body);
      if (results is! Map<String, dynamic>) {
        return null;
      }

      final gameData = results['pageProps']?['game']?['data']?['game'];
      if (gameData is! List || gameData.length != 1) {
        return null;
      }

      final item = gameData.first;
      if (item is! Map<String, dynamic>) {
        return null;
      }

      if (item['game_id'] is! num ||
          item['comp_main'] is! num ||
          item['comp_plus'] is! num ||
          item['comp_100'] is! num ||
          item['comp_all'] is! num) {
        return null;
      }

      return item;
    } catch (_) {
      return null;
    }
  }

  List<String> _parsePlatforms(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) {
      return const [];
    }

    return raw
        .split(',')
        .map((platform) => platform.trim())
        .where((platform) => platform.isNotEmpty)
        .toList();
  }

  String _buildImageUrl(dynamic gameImage) {
    final image = gameImage?.toString() ?? '';
    if (image.isEmpty) {
      return '';
    }

    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }

    return '$_imageUrl$image';
  }

  int _secondsToHours(dynamic value) {
    final seconds =
        value is num ? value : num.tryParse(value?.toString() ?? '');
    if (seconds == null || seconds <= 0) {
      return 0;
    }

    return (seconds / 3600).round();
  }

  List<_RankedHltbResult> _rankResults(
    String query,
    List<Map<String, dynamic>> results,
  ) {
    final normalizedQuery = query.normalizeForSearch();

    final ranked = results.map((item) {
      final rawName = (item['game_name'] ?? '').toString();
      final normalizedName = rawName.normalizeForSearch();
      final distance = _levenshtein(normalizedQuery, normalizedName);
      final maxLength = max(normalizedQuery.length, normalizedName.length);
      final similarity = maxLength == 0
          ? 0.0
          : ((maxLength - distance) / maxLength).clamp(0.0, 1.0);

      return _RankedHltbResult(
        item: item,
        gameId: _toInt(item['game_id']),
        name: rawName,
        isExactMatch:
            normalizedQuery.isNotEmpty && normalizedQuery == normalizedName,
        distance: distance,
        popularity: _toInt(item['comp_all_count']),
        similarity: similarity.toDouble(),
      );
    }).toList();

    ranked.sort((a, b) {
      if (a.isExactMatch != b.isExactMatch) {
        return a.isExactMatch ? -1 : 1;
      }

      if (a.distance != b.distance) {
        return a.distance.compareTo(b.distance);
      }

      return b.popularity.compareTo(a.popularity);
    });

    return ranked;
  }

  int _levenshtein(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }

    var previous = List<int>.generate(b.length + 1, (index) => index);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;

      for (var j = 0; j < b.length; j++) {
        final substitutionCost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        current[j + 1] = min(
          min(current[j] + 1, previous[j + 1] + 1),
          previous[j] + substitutionCost,
        );
      }

      final temp = previous;
      previous = current;
      current = temp;
    }

    return previous[b.length];
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _SearchAuth {
  final String token;
  final String hpKey;
  final String hpVal;

  const _SearchAuth({
    required this.token,
    required this.hpKey,
    required this.hpVal,
  });
}

class _RankedHltbResult {
  final Map<String, dynamic> item;
  final int gameId;
  final String name;
  final bool isExactMatch;
  final int distance;
  final int popularity;
  final double similarity;

  const _RankedHltbResult({
    required this.item,
    required this.gameId,
    required this.name,
    required this.isExactMatch,
    required this.distance,
    required this.popularity,
    required this.similarity,
  });
}
