import 'dart:convert';

import 'package:dio/dio.dart';

enum ScreenScraperArtType {
  screenshot('ss', ['media_screenshot']),
  titleScreenshot('sstitle', ['media_sstitle']),
  fanart('fanart', ['media_fanart']),
  steamGrid('steamgrid', ['media_steamgrid']),
  logo('wheel', ['media_wheel_']),
  logoHd('wheel-hd', ['media_wheelhd_', 'media_wheel_hd_']),
  marquee('marquee', ['media_marquee']),
  screenMarquee('screenmarquee', ['media_screenmarquee']),
  box2d('box-2D', ['media_boitier_2d_']),
  box3d('box-3D', ['media_boitier_3d_']),
  boxTexture('box-texture', ['media_boitier_texture_']),
  flyer('flyer', ['media_flyer_']),
  figurine('figurine', ['media_figurine']);

  const ScreenScraperArtType(this.media, this.mediaKeys);

  final String media;
  final List<String> mediaKeys;
}

class ScreenScraperScraper {
  static const String _baseUrl = 'https://api.screenscraper.fr/api2';

  final Dio _dio;
  final String developerId;
  final String developerPassword;
  final String softName;
  final String? username;
  final String? password;

  ScreenScraperScraper({
    required this.developerId,
    required this.developerPassword,
    required this.softName,
    this.username,
    this.password,
    Dio? dio,
  }) : _dio = _createDio(dio);

  Future<List<ScreenScraperArt>> search(
    String query,
    ScreenScraperArtType type, {
    int? systemId,
  }) async {
    var params = {
      ..._authQueryParameters,
      if (systemId != null) 'systemeid': systemId,
      'recherche': query,
    };
    print(params);
    final response = await _dio.get(
      '/jeuRecherche.php',
      queryParameters: params,
      options: Options(responseType: ResponseType.plain),
    );
    print("ScreenScraper response: ${response.data}");
    final data = _decodeResponse(response);
    _throwIfApiError(data);

    final games = _extractGames(data);
    final arts = <ScreenScraperArt>[];

    for (final game in games) {
      arts.addAll(_extractArts(game, type));
    }

    return _dedupeByUrl(arts);
  }

  Map<String, dynamic> get _authQueryParameters {
    return {
      'devid': developerId,
      'devpassword': developerPassword,
      'softname': softName,
      'output': 'json',
      if (username != null && username!.isNotEmpty) 'ssid': username,
      if (password != null && password!.isNotEmpty) 'sspassword': password,
    };
  }

  List<ScreenScraperGame> _extractGames(dynamic data) {
    final responseData = _asMap(data);
    final response = _asMap(responseData['response']);
    final gamesData = response['jeux'] ?? response['jeu'];

    return _asGameMaps(gamesData)
        .map(ScreenScraperGame.fromJson)
        .where((game) => game.id != null)
        .toList();
  }

  List<ScreenScraperArt> _extractArts(
    ScreenScraperGame game,
    ScreenScraperArtType type,
  ) {
    final urls = <ScreenScraperArt>[];

    _collectArtUrls(
      game.medias,
      type,
      game,
      urls,
    );

    return urls;
  }

  void _collectArtUrls(
    dynamic value,
    ScreenScraperArtType type,
    ScreenScraperGame game,
    List<ScreenScraperArt> arts, [
    String? currentKey,
  ]) {
    if (value is Map) {
      value.forEach((key, childValue) {
        _collectArtUrls(
          childValue,
          type,
          game,
          arts,
          key.toString(),
        );
      });
      return;
    }

    if (value is List) {
      for (final childValue in value) {
        _collectArtUrls(
          childValue,
          type,
          game,
          arts,
          currentKey,
        );
      }
      return;
    }

    if (value is! String || currentKey == null) return;
    if (!_matchesMediaKey(currentKey, type) || !_isUrl(value)) return;

    arts.add(
      ScreenScraperArt(
        url: value,
        type: type,
        game: game,
        mediaKey: currentKey,
        region: _regionFromMediaKey(currentKey),
      ),
    );
  }

  bool _matchesMediaKey(String key, ScreenScraperArtType type) {
    final normalizedKey = key.toLowerCase();

    return type.mediaKeys.any((mediaKey) {
      final normalizedMediaKey = mediaKey.toLowerCase();
      if (normalizedMediaKey.endsWith('_')) {
        return normalizedKey.startsWith(normalizedMediaKey);
      }

      return normalizedKey == normalizedMediaKey;
    });
  }

  List<ScreenScraperArt> _dedupeByUrl(List<ScreenScraperArt> arts) {
    final seen = <String>{};
    final uniqueArts = <ScreenScraperArt>[];

    for (final art in arts) {
      if (seen.add(art.url)) {
        uniqueArts.add(art);
      }
    }

    return uniqueArts;
  }

  static String? _regionFromMediaKey(String key) {
    final parts = key.split('_');
    if (parts.length < 3) return null;

    final region = parts.last;
    return region.length <= 4 ? region : null;
  }

  static bool _isUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  static List<Map<String, dynamic>> _asGameMaps(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (value is Map) {
      if (value.containsKey('jeu')) {
        return _asGameMaps(value['jeu']);
      }

      if (value.containsKey('id') || value.containsKey('nom')) {
        return [Map<String, dynamic>.from(value)];
      }

      return value.values.expand(_asGameMaps).toList();
    }

    return [];
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static dynamic _decodeResponse(Response<dynamic> response) {
    final data = response.data;

    if (data is Map || data is List) return data;

    final body = data?.toString().trim() ?? '';
    if (body.isEmpty) {
      throw ScreenScraperException(
        'ScreenScraper returned an empty response.',
        statusCode: response.statusCode,
      );
    }

    if (!_looksLikeJson(body)) {
      throw ScreenScraperException(
        'ScreenScraper returned a non-JSON response. Check your ScreenScraper credentials.',
        statusCode: response.statusCode,
        responsePreview: _preview(body),
      );
    }

    try {
      return jsonDecode(body);
    } on FormatException catch (error) {
      throw ScreenScraperException(
        'ScreenScraper returned invalid JSON: ${error.message}',
        statusCode: response.statusCode,
        responsePreview: _preview(body),
      );
    }
  }

  static bool _looksLikeJson(String body) {
    return body.startsWith('{') || body.startsWith('[');
  }

  static void _throwIfApiError(dynamic data) {
    final responseData = _asMap(data);
    final response = _asMap(responseData['response']);
    final error = responseData['erreur'] ??
        responseData['erreurs'] ??
        response['erreur'] ??
        response['erreurs'];

    if (error != null) {
      throw ScreenScraperException(
        'ScreenScraper API error: ${_errorMessage(error)}',
      );
    }
  }

  static String _errorMessage(dynamic error) {
    if (error is String) return error;
    if (error is Map) {
      return error.values.map((value) => value.toString()).join(' ');
    }
    if (error is List) {
      return error.map((value) => value.toString()).join(' ');
    }

    return error.toString();
  }

  static String _preview(String body) {
    const maxLength = 240;
    return body.length <= maxLength
        ? body
        : '${body.substring(0, maxLength)}...';
  }

  static Dio _createDio(Dio? dio) {
    final client = dio ?? Dio();
    client.options.baseUrl =
        client.options.baseUrl.isEmpty ? _baseUrl : client.options.baseUrl;
    return client;
  }
}

class ScreenScraperException implements Exception {
  final String message;
  final int? statusCode;
  final String? responsePreview;

  const ScreenScraperException(
    this.message, {
    this.statusCode,
    this.responsePreview,
  });

  @override
  String toString() {
    final details = [
      if (statusCode != null) 'statusCode: $statusCode',
      if (responsePreview != null) 'responsePreview: $responsePreview',
    ];

    return details.isEmpty ? message : '$message (${details.join(', ')})';
  }
}

class ScreenScraperGame {
  final int? id;
  final String name;
  final int? systemId;
  final String? systemName;
  final Map<String, dynamic> medias;

  ScreenScraperGame({
    required this.id,
    required this.name,
    required this.systemId,
    required this.systemName,
    required this.medias,
  });

  factory ScreenScraperGame.fromJson(Map<String, dynamic> json) {
    final system = _asMap(json['systeme']);

    return ScreenScraperGame(
      id: _tryParseInt(json['id']),
      name: json['nom']?.toString() ?? _extractName(json['noms']),
      systemId: _tryParseInt(system['id']),
      systemName: system['nom']?.toString(),
      medias: _asMap(json['medias']),
    );
  }

  static String _extractName(dynamic value) {
    final names = _asMap(value);
    if (names.isEmpty) return '';

    for (final key in ['nom_us', 'nom_wor', 'nom_eu', 'nom_ss']) {
      final name = names[key]?.toString();
      if (name != null && name.isNotEmpty) return name;
    }

    for (final value in names.values) {
      final name = value.toString();
      if (name.isNotEmpty) return name;
    }

    return '';
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class ScreenScraperArt {
  final String url;
  final ScreenScraperArtType type;
  final ScreenScraperGame game;
  final String mediaKey;
  final String? region;

  ScreenScraperArt({
    required this.url,
    required this.type,
    required this.game,
    required this.mediaKey,
    this.region,
  });
}
