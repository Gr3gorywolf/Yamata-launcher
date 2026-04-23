import 'package:dio/dio.dart';

enum SteamGridArtType {
  grids('grids'),
  heroes('heroes'),
  logos('logos'),
  icons('icons');

  const SteamGridArtType(this.endpoint);

  final String endpoint;
}

class SteamGridScraper {
  static const String _baseUrl = 'https://www.steamgriddb.com/api/v2';

  final Dio _dio;

  SteamGridScraper({
    required String apiKey,
    Dio? dio,
  }) : _dio = _createDio(apiKey, dio);

  Future<List<SteamGridArt>> search(
    String query,
    SteamGridArtType type,
  ) async {
    final game = await _findGame(query);
    if (game == null) return [];

    final response = await _dio.get('/${type.endpoint}/game/${game.id}');
    final responseData = _asMap(response.data);
    final data = responseData['data'];

    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((item) => SteamGridArt.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<SteamGridGame?> _findGame(String query) async {
    final response = await _dio.get(
      '/search/autocomplete/${Uri.encodeComponent(query)}',
    );
    final responseData = _asMap(response.data);
    final data = responseData['data'];

    if (data is! List || data.isEmpty) return null;

    final firstGame = data.first;
    if (firstGame is! Map) return null;

    return SteamGridGame.fromJson(Map<String, dynamic>.from(firstGame));
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static Dio _createDio(String apiKey, Dio? dio) {
    final client = dio ?? Dio();
    client.options.baseUrl = client.options.baseUrl.isEmpty
        ? _baseUrl
        : client.options.baseUrl;
    client.options.headers['Authorization'] = 'Bearer $apiKey';
    return client;
  }
}

class SteamGridGame {
  final int id;
  final String name;

  SteamGridGame({
    required this.id,
    required this.name,
  });

  factory SteamGridGame.fromJson(Map<String, dynamic> json) {
    return SteamGridGame(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
    );
  }
}

class SteamGridArt {
  final int id;
  final String url;
  final String thumbnail;
  final String? style;
  final String? mime;
  final int? width;
  final int? height;

  SteamGridArt({
    required this.id,
    required this.url,
    required this.thumbnail,
    this.style,
    this.mime,
    this.width,
    this.height,
  });

  factory SteamGridArt.fromJson(Map<String, dynamic> json) {
    return SteamGridArt(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      url: json['url']?.toString() ?? '',
      thumbnail: json['thumb']?.toString() ?? '',
      style: json['style']?.toString(),
      mime: json['mime']?.toString(),
      width: _tryParseInt(json['width']),
      height: _tryParseInt(json['height']),
    );
  }

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
