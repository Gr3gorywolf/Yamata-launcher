import 'dart:async';

import 'package:dio/dio.dart';
import 'package:yamata_launcher/models/contracts/debrider.dart';
import 'package:yamata_launcher/services/debrider_service.dart';
import 'package:yamata_launcher/utils/torrent_helper.dart';

class AllDebridDebrider implements Debrider {
  static const List<String> _supportedHosters = [
    "1fichier.com",
    "mediafire.com",
    "ddownload.com",
  ];
  static const String _baseUrl = "https://api.alldebrid.com/v4";
  static const String _agent = "Yamata Launcher";
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const int _rlPerSecond = 10;
  static const int _rlPerMinute = 500;
  static const int _rlRetryMax = 5;
  static const int _rlRetryBaseMs = 2000;
  static const Duration _delayedPollInterval = Duration(seconds: 5);
  static const int _delayedMaxAttempts = 120;

  static final List<DateTime> _requestTimestamps = [];
  static Future<void> _throttleChain = Future.value();

  @override
  String get name => "AllDebrid";

  @override
  String get settingKey => "alldebrid";

  @override
  Future<bool> isAuthenticated() async {
    final credentials = await DebriderService.getDebriderCredentials(this);
    final apiKey = credentials?.apiKey?.trim();

    return apiKey != null && apiKey.isNotEmpty;
  }

  @override
  bool canHandleUrl(String url) {
    return TorrentHelper.isMagnetUri(url) ||
        _supportedHosters.any((host) => url.contains(host));
  }

  @override
  Future<String> getDirectDownloadLink(String uri) async {
    final client = await _authorizedClient();

    try {
      return await _getDownloadUrl(client, uri);
    } on DioException catch (error) {
      throw Exception(_formatDioError(error));
    } finally {
      client.close(force: true);
    }
  }

  Future<Dio> _authorizedClient() async {
    final apiKey = await _getApiKey();

    final client = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: {
          "Authorization": "Bearer $apiKey",
          "Content-Type": Headers.formUrlEncodedContentType,
        },
        sendTimeout: _requestTimeout,
        connectTimeout: _requestTimeout,
        receiveTimeout: _requestTimeout,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _throttle();
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          if (status != 429 && status != 503) {
            handler.next(error);
            return;
          }

          final requestOptions = error.requestOptions;
          final retryCount = (requestOptions.extra["rlRetry"] as int?) ?? 0;

          if (retryCount >= _rlRetryMax) {
            handler.next(error);
            return;
          }

          requestOptions.extra["rlRetry"] = retryCount + 1;
          final delayMs = _rlRetryBaseMs * (1 << retryCount);
          await Future.delayed(Duration(milliseconds: delayMs));

          try {
            final response = await client.fetch<dynamic>(requestOptions);
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );

    return client;
  }

  static Future<void> _throttle() {
    _throttleChain = _throttleChain.then((_) => _applyThrottle());
    return _throttleChain;
  }

  static Future<void> _applyThrottle() async {
    final now = DateTime.now();
    _requestTimestamps.removeWhere(
      (timestamp) => now.difference(timestamp) >= const Duration(minutes: 1),
    );

    final inLastSecond = _requestTimestamps
        .where((timestamp) => now.difference(timestamp).inMilliseconds < 1000)
        .toList();

    if (inLastSecond.length >= _rlPerSecond) {
      final oldest = inLastSecond.first;
      final waitMs = 1000 - now.difference(oldest).inMilliseconds + 50;
      if (waitMs > 0) {
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }

    if (_requestTimestamps.length >= _rlPerMinute) {
      final oldest = _requestTimestamps.first;
      final waitMs =
          60000 - DateTime.now().difference(oldest).inMilliseconds + 50;
      if (waitMs > 0) {
        await Future.delayed(Duration(milliseconds: waitMs));
      }
    }

    _requestTimestamps.add(DateTime.now());
  }

  Future<String> _getDownloadUrl(Dio client, String uri) async {
    if (!TorrentHelper.isMagnetUri(uri)) {
      final unlockedUrl = await _unlockDownloadLink(client, uri);
      return Uri.decodeComponent(unlockedUrl);
    }

    final magnetId = await _getMagnetId(client, uri);
    if (magnetId == null) {
      throw Exception("AllDebrid could not resolve the magnet id.");
    }

    final magnets = await _getMagnetStatus(client, magnetId);
    final magnetStatus = magnets.isNotEmpty ? magnets.first : null;
    final statusCode = _toInt(magnetStatus?["statusCode"]);
    final status = magnetStatus?["status"]?.toString() ?? "unknown";

    if (statusCode != null && statusCode >= 5) {
      throw Exception(
        "AllDebrid magnet is in an error state: $status (code=$statusCode).",
      );
    }

    if (statusCode != null && statusCode != 4) {
      throw Exception(
        "Torrent is not ready in AllDebrid yet: $status (code=$statusCode). Try again in a few moments.",
      );
    }

    final links = await _getMagnetFiles(client, magnetId);
    if (links.isEmpty) {
      throw Exception("AllDebrid returned no downloadable files for magnet.");
    }

    final firstLink = links.first["link"]?.toString();
    if (firstLink == null || firstLink.isEmpty) {
      throw Exception("AllDebrid returned an invalid magnet file link.");
    }

    final unlockedUrl = await _unlockDownloadLink(client, firstLink);
    return Uri.decodeComponent(unlockedUrl);
  }

  Future<Map<String, dynamic>> _unlockLink(Dio client, String link) async {
    final response = await client.post<Map<String, dynamic>>(
      "/link/unlock",
      queryParameters: await _searchParams(),
      data: {"link": link},
    );

    final data = _requireSuccessData(
      response.data,
      "Failed to unlock link in AllDebrid.",
    );

    var unlockedLink = data["link"]?.toString();
    final delayedId = _toInt(data["delayed"]);

    if ((unlockedLink == null || unlockedLink.isEmpty) && delayedId != null) {
      unlockedLink = await _waitForDelayedLink(client, delayedId);
    }

    if (unlockedLink == null || unlockedLink.isEmpty) {
      throw Exception(
        "AllDebrid did not return a download link or delayed id.",
      );
    }

    return {
      ...data,
      "link": unlockedLink,
    };
  }

  Future<String> _unlockDownloadLink(Dio client, String link) async {
    final data = await _unlockLink(client, link);
    final unlockedLink = data["link"]?.toString();

    if (unlockedLink == null || unlockedLink.isEmpty) {
      throw Exception("AllDebrid did not return a valid unlocked link.");
    }

    return unlockedLink;
  }

  Future<String> _waitForDelayedLink(Dio client, int delayedId) async {
    for (var attempt = 1; attempt <= _delayedMaxAttempts; attempt++) {
      await Future.delayed(_delayedPollInterval);

      final response = await client.post<Map<String, dynamic>>(
        "/link/delayed",
        queryParameters: await _searchParams(),
        data: {"id": delayedId.toString()},
      );

      final data = _requireSuccessData(
        response.data,
        "Failed to retrieve delayed AllDebrid link.",
      );

      final status = _toInt(data["status"]);
      final link = data["link"]?.toString();

      if (status == 2 && link != null && link.isNotEmpty) {
        return link;
      }

      if (status == 3) {
        throw Exception("AllDebrid delayed link generation failed.");
      }
    }

    throw Exception(
      "AllDebrid delayed link timed out after $_delayedMaxAttempts attempts.",
    );
  }

  Future<List<Map<String, dynamic>>> _getMagnetStatus(
    Dio client, [
    int? id,
  ]) async {
    final payload = {
      "agent": _agent,
      if (id != null) "id": id.toString(),
    };

    final response = await client.post<Map<String, dynamic>>(
      "https://api.alldebrid.com/v4.1/magnet/status",
      data: payload,
    );

    final data = _requireSuccessData(
      response.data,
      "Failed to fetch AllDebrid magnet status.",
    );

    return _normalizeMagnets(data["magnets"]);
  }

  Future<List<Map<String, dynamic>>> _getMagnetFiles(Dio client, int id) async {
    Future<List<Map<String, dynamic>>> requestMagnetFiles(
        String endpoint) async {
      final response = await client.post<Map<String, dynamic>>(
        endpoint,
        data: {
          "agent": _agent,
          "id[]": id.toString(),
        },
      );

      final data = _requireSuccessData(
        response.data,
        "Failed to fetch AllDebrid magnet files.",
      );

      final magnets = _normalizeMagnetFiles(data["magnets"]);
      final firstMagnet = magnets.isNotEmpty ? magnets.first : null;
      final error = firstMagnet?["error"];

      if (error is Map && error.isNotEmpty) {
        return const [];
      }

      final files = firstMagnet?["files"];
      if (files is! List) {
        return const [];
      }

      return _extractFileEntries(List<Map<String, dynamic>>.from(
        files.whereType<Map>().map((item) => Map<String, dynamic>.from(item)),
      ));
    }

    try {
      return await requestMagnetFiles(
        "https://api.alldebrid.com/v4.1/magnet/files",
      );
    } catch (_) {
      return requestMagnetFiles("https://api.alldebrid.com/v4/magnet/files");
    }
  }

  Future<List<Map<String, dynamic>>> _addMagnet(
      Dio client, String magnet) async {
    final response = await client.post<Map<String, dynamic>>(
      "/magnet/upload",
      queryParameters: await _searchParams(),
      data: {
        "agent": _agent,
        "magnets[]": magnet,
      },
    );

    final data = _requireSuccessData(
      response.data,
      "Failed to add magnet to AllDebrid.",
    );

    return _normalizeMagnets(data["magnets"]);
  }

  Future<int?> _getMagnetId(Dio client, String magnetUri) async {
    String? infoHash;

    try {
      infoHash = TorrentHelper.extractInfoHash(magnetUri);
    } catch (_) {
      infoHash = null;
    }

    if (infoHash == null || infoHash.isEmpty) {
      return null;
    }

    final userMagnets = await _getMagnetStatus(client);
    final existingMagnet = userMagnets.firstWhere(
      (magnet) => magnet["hash"]?.toString().toLowerCase() == infoHash,
      orElse: () => const {},
    );

    final existingId = _toInt(existingMagnet["id"]);
    if (existingId != null) {
      return existingId;
    }

    final uploadedMagnets = await _addMagnet(client, magnetUri);
    if (uploadedMagnets.isEmpty) {
      return null;
    }

    return _toInt(uploadedMagnets.first["id"]);
  }

  Future<Map<String, String>> _searchParams([
    Map<String, String>? params,
  ]) async {
    return {
      "apikey": await _getApiKey(),
      "agent": _agent,
      ...?params,
    };
  }

  Future<String> _getApiKey() async {
    final credentials = await DebriderService.getDebriderCredentials(this);
    final apiKey = credentials?.apiKey?.trim();

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("AllDebrid API key is not configured.");
    }

    return apiKey;
  }

  Map<String, dynamic> _requireSuccessData(
    Map<String, dynamic>? payload,
    String fallbackMessage,
  ) {
    if (payload == null) {
      throw Exception(fallbackMessage);
    }

    final status = payload["status"]?.toString();
    if (status == "error") {
      final error = payload["error"];
      if (error is Map && error["message"] != null) {
        throw Exception(error["message"].toString());
      }
      throw Exception(fallbackMessage);
    }

    final data = payload["data"];
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {"value": data};
  }

  List<Map<String, dynamic>> _normalizeMagnets(dynamic magnets) {
    if (magnets is List) {
      return magnets
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (magnets is Map) {
      if (magnets.containsKey("id") && magnets.containsKey("hash")) {
        return [Map<String, dynamic>.from(magnets)];
      }

      return magnets.values
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return const [];
  }

  List<Map<String, dynamic>> _normalizeMagnetFiles(dynamic magnets) {
    if (magnets is List) {
      return magnets
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (magnets is Map) {
      if (magnets.containsKey("id")) {
        return [Map<String, dynamic>.from(magnets)];
      }

      return magnets.values
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return const [];
  }

  List<Map<String, dynamic>> _extractFileEntries(
    List<Map<String, dynamic>> files, [
    List<String> parentPath = const [],
  ]) {
    final entries = <Map<String, dynamic>>[];

    for (final node in files) {
      final nodeLink = node["l"]?.toString();
      final nodeName = node["n"]?.toString();

      if (nodeLink != null && nodeLink.isNotEmpty) {
        final fileName = nodeName ?? _extractFilenameFromLink(nodeLink);
        entries.add({
          "link": nodeLink,
          "relativePath": [...parentPath, fileName].join("/"),
          "size": _toInt(node["s"]),
        });
      }

      final children = node["e"];
      if (children is List && children.isNotEmpty) {
        final nextParentPath = nodeName != null && nodeName.isNotEmpty
            ? [...parentPath, nodeName]
            : parentPath;

        entries.addAll(
          _extractFileEntries(
            children
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList(),
            nextParentPath,
          ),
        );
      }
    }

    return entries;
  }

  String _extractFilenameFromLink(String link) {
    try {
      final parsed = Uri.parse(link);
      final segments =
          parsed.pathSegments.where((segment) => segment.isNotEmpty);

      if (segments.isEmpty) {
        return "file";
      }

      return segments.last;
    } catch (_) {
      return "file";
    }
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? "");
  }

  String _formatDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (data is Map) {
      final responseError = data["error"];
      if (responseError is Map && responseError["message"] != null) {
        return responseError["message"].toString();
      }

      if (data["message"] != null) {
        return data["message"].toString();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    if (statusCode != null) {
      return "AllDebrid request failed with status $statusCode.";
    }

    return error.message ?? "Unknown AllDebrid error.";
  }
}
