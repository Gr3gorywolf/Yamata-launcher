import 'package:dio/dio.dart';
import 'package:yamata_launcher/models/contracts/debrider.dart';
import 'package:yamata_launcher/models/exceptions/debrider_is_processing_exception.dart';
import 'package:yamata_launcher/services/debrider_service.dart';
import 'package:yamata_launcher/utils/torrent_helper.dart';

class TorboxDebrider implements Debrider {
  static const String _baseUrl = "https://api.torbox.app/v1/api";
  static const Duration _requestTimeout = Duration(seconds: 20);

  @override
  String get name => "Torbox";

  @override
  String get settingKey => "torbox";

  @override
  Future<bool> isAuthenticated() async {
    final credentials = await DebriderService.getDebriderCredentials(this);
    final apiKey = credentials?.apiKey?.trim();

    return apiKey != null && apiKey.isNotEmpty;
  }

  @override
  bool canHandleUrl(String url) {
    return TorrentHelper.isMagnetUri(url);
  }

  @override
  Future<String> getDirectDownloadLink(String magnetUrl) async {
    if (!TorrentHelper.isMagnetUri(magnetUrl)) {
      throw Exception("Torbox only supports magnet links.");
    }

    final client = await _authorizedClient();

    try {
      final torrentData = await _getTorrentIdAndName(client, magnetUrl);
      final link = await _requestLink(client, torrentData.id);

      if (link.isEmpty) {
        throw Exception("Torbox did not return a download URL.");
      }

      return link;
    } on DioException catch (error) {
      var dioExMessage = _formatDioError(error);
      print(error);
      if (dioExMessage.contains(
          "There was an error processing your request. Please try again later")) {
        throw DebriderIsProcessingException("Status Processing");
      }
      print("TorboxDebrider DioException: $dioExMessage");
      throw Exception(dioExMessage);
    } finally {
      client.close(force: true);
    }
  }

  Future<Dio> _authorizedClient() async {
    final credentials = await DebriderService.getDebriderCredentials(this);
    final apiKey = credentials?.apiKey?.trim();

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Torbox API key is not configured.");
    }

    return Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        headers: {
          "Authorization": "Bearer $apiKey",
          "User-Agent": "Yamata Launcher",
        },
        sendTimeout: _requestTimeout,
        connectTimeout: _requestTimeout,
        receiveTimeout: _requestTimeout,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  Future<_TorboxTorrentData> _addMagnet(Dio client, String magnet) async {
    final response = await client.post<Map<String, dynamic>>(
      "/torrents/createtorrent",
      data: FormData.fromMap({"magnet": magnet}),
    );

    final data = _requireSuccessData(
      response.data,
      "Failed to add magnet to Torbox.",
    );

    final torrentId = data["torrent_id"];
    if (torrentId is! num) {
      throw Exception("Torbox did not return a torrent id.");
    }

    return _TorboxTorrentData(
      id: torrentId.toInt(),
      name: data["name"]?.toString(),
    );
  }

  Future<List<Map<String, dynamic>>> _getAllTorrentsFromUser(Dio client) async {
    final response = await client.get<Map<String, dynamic>>("/torrents/mylist");
    final data = _requireSuccessData(
      response.data,
      "Failed to fetch Torbox torrents.",
    );

    final items = data is List ? data : const [];
    return items.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item.cast<String, dynamic>());
    }).toList();
  }

  Future<_TorboxTorrentData> _getTorrentIdAndName(
    Dio client,
    String magnetUri,
  ) async {
    final userTorrents = await _getAllTorrentsFromUser(client);
    final infoHash = TorrentHelper.extractInfoHash(magnetUri);

    final existingTorrent = userTorrents.firstWhere(
      (userTorrent) =>
          userTorrent["hash"]?.toString().toLowerCase() == infoHash,
      orElse: () => const {},
    );

    final existingId = existingTorrent["id"];
    if (existingId is num) {
      return _TorboxTorrentData(
        id: existingId.toInt(),
        name: existingTorrent["name"]?.toString(),
      );
    }

    return _addMagnet(client, magnetUri);
  }

  Future<String> _requestLink(Dio client, int torrentId) async {
    final apiKey = await _getApiKey();

    final response = await client.get<Map<String, dynamic>>(
      "/torrents/requestdl",
      queryParameters: {
        "token": apiKey,
        "torrent_id": torrentId.toString(),
        "zip_link": "true",
        "append_name": "true",
      },
    );

    final data = _requireSuccessData(
      response.data,
      "Failed to request Torbox download link.",
    );

    if (data is String && data.isNotEmpty) {
      return data;
    }

    if (data is Map && data["url"] != null) {
      return data["url"].toString();
    }

    throw Exception("Torbox did not return a valid download URL.");
  }

  Future<String> _getApiKey() async {
    final credentials = await DebriderService.getDebriderCredentials(this);
    final apiKey = credentials?.apiKey?.trim();

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Torbox API key is not configured.");
    }

    return apiKey;
  }

  dynamic _requireSuccessData(
    Map<String, dynamic>? data,
    String fallbackMessage,
  ) {
    if (data == null) {
      throw Exception(fallbackMessage);
    }

    final success = data["success"];
    if (success is bool && !success) {
      throw Exception(data["detail"]?.toString() ?? fallbackMessage);
    }

    if (!data.containsKey("data")) {
      throw Exception(data["detail"]?.toString() ?? fallbackMessage);
    }

    return data["data"];
  }

  String _formatDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (data is Map) {
      if (data["detail"] != null) {
        return data["detail"].toString();
      }
      if (data["error"] != null) {
        return data["error"].toString();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    if (statusCode != null) {
      return "Torbox request failed with status $statusCode.";
    }

    return error.message ?? "Unknown Torbox error.";
  }
}

class _TorboxTorrentData {
  final int id;
  final String? name;

  const _TorboxTorrentData({
    required this.id,
    required this.name,
  });
}
