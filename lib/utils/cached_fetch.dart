import 'dart:convert';
import 'package:http/http.dart';
import 'package:yamata_launcher/models/contracts/json_serializable.dart';
import 'package:yamata_launcher/services/cache_service.dart';

typedef FromJson<T> = T Function(Map<String, dynamic> json);
typedef FromRawJson<T> = T Function(dynamic json);

class CachedFetch {
  static _getFullkey(String key) {
    return "fetch-cache/" + key;
  }

  static Future<T?> withContentLengthSignature<T>({
    required String key,
    required String url,
    required FromRawJson<T> parser,
    Duration? ttl,
    Client? client,
    Duration? timeout,
    bool forceCache = false,
  }) async {
    client ??= Client();

    final fullKey = _getFullkey(key);

    try {
      final signature = await CacheService.getCacheSignature(fullKey);
      if (forceCache && signature != null) {
        final cached = await CacheService.retrieveCacheFile(fullKey);
        if (cached != null) {
          return parser(jsonDecode(cached));
        }
      }

      if (signature != null) {
        final head = await client.head(Uri.parse(url));

        final remoteSignature =
            head.headers['etag'] ?? head.headers['content-length'];

        if (remoteSignature != null && remoteSignature == signature) {
          final cached = await CacheService.retrieveCacheFile(fullKey);
          if (cached != null) {
            return parser(jsonDecode(cached));
          }
        }
      }

      final res = await client
          .get(Uri.parse(url))
          .timeout(timeout ?? Duration(seconds: 25));
      if (res.statusCode != 200) return null;

      await CacheService.writeCacheFile(fullKey, res.body, ttl: ttl);

      final newSignature = res.headers['etag'] ?? res.headers['content-length'];

      if (newSignature != null) {
        await CacheService.setCacheSignature(fullKey, newSignature);
      }

      return parser(jsonDecode(res.body));
    } catch (e, st) {
      print('CachedFetch<json> [$key]: $e');
      print(st);

      final cached = await CacheService.retrieveCacheFile(fullKey);
      if (cached != null) {
        try {
          return parser(jsonDecode(cached));
        } catch (_) {}
      }

      return null;
    }
  }

  // Object fetcher
  static Future<T?> object<T extends JsonSerializable>({
    required String key,
    required Future<T?> Function() fetcher,
    required FromJson<T> fromJson,
    Duration? ttl,
  }) async {
    try {
      final cached = await CacheService.retrieveCacheFile(_getFullkey(key));
      if (cached != null) {
        return fromJson(json.decode(cached));
      }

      final result = await fetcher();
      if (result == null) return null;

      await CacheService.writeCacheFile(
        _getFullkey(key),
        json.encode(result.toJson()),
        ttl: ttl,
      );

      return result;
    } catch (e, st) {
      print('CachedFetch<object> [$key]: $e');
      print(st);
      return null;
    }
  }

  // List fetcher
  static Future<List<T>> list<T extends JsonSerializable>({
    required String key,
    required Future<List<T>> Function() fetcher,
    required FromJson<T> fromJson,
    Duration? ttl,
  }) async {
    try {
      final cached = await CacheService.retrieveCacheFile(_getFullkey(key));
      if (cached != null) {
        final decoded = json.decode(cached) as List;
        return decoded.map((e) => fromJson(e as Map<String, dynamic>)).toList();
      }

      final result = await fetcher();

      await CacheService.writeCacheFile(
        _getFullkey(key),
        json.encode(result.map((e) => e.toJson()).toList()),
        ttl: ttl,
      );

      return result;
    } catch (e, st) {
      print('CachedFetch<list> [$key]: $e');
      print(st);
      return [];
    }
  }
}
