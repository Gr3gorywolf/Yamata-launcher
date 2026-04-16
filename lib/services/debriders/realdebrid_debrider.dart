import 'package:dio/dio.dart';
import 'package:yamata_launcher/models/contracts/debrider.dart';
import 'package:yamata_launcher/models/exceptions/debrider_is_processing_exception.dart';
import 'package:yamata_launcher/services/debrider_service.dart';
import 'package:yamata_launcher/utils/torrent_helper.dart';

class RealdebridDebrider implements Debrider {
  static const String _baseUrl = "https://api.real-debrid.com/rest/1.0";
  static const Duration _requestTimeout = Duration(seconds: 20);

  static const List<String> _supportedHosters = [
    "1fichier.com",
    "mediafire.com",
    "drive.google.com",
    "dropbox.com",
    "mega.nz",
    "ddownload.com",
    "send.cm",
    "send.now"
  ];

  @override
  String get name => "Realdebrid";

  @override
  String get settingKey => "realdebrid";

  @override
  Future<bool> isAuthenticated() async {
    final credentials = await DebriderService.getDebriderCredentials(this);
    if (credentials?.apiKey == null || credentials!.apiKey!.trim().isEmpty) {
      return false;
    }
    return true;
  }

  @override
  bool canHandleUrl(String url) {
    return TorrentHelper.isMagnetUri(url) ||
        _supportedHosters.any((host) => url.contains(host));
  }

  @override
  Future<String> getDirectDownloadLink(String magnetUrl) async {
    final client = await _authorizedClient();

    try {
      return await _getDownloadUrl(client, magnetUrl);
    } on DioException catch (error) {
      throw Exception(_formatDioError(error));
    } finally {
      client.close(force: true);
    }
  }

  Future<Dio> _authorizedClient() async {
    final credentials = await DebriderService.getDebriderCredentials(this);
    final apiKey = credentials?.apiKey?.trim();

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Real-Debrid API key is not configured.");
    }

    return Dio(
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
  }

  Future<String> _getDownloadUrl(Dio client, String uri) async {
    String? realDebridTorrentId;

    if (TorrentHelper.isMagnetUri(uri)) {
      realDebridTorrentId = await _getTorrentId(client, uri);
    }

    if (realDebridTorrentId != null) {
      var torrentInfo = await _getTorrentInfo(client, realDebridTorrentId);

      if (torrentInfo["status"] == "waiting_files_selection") {
        await _selectAllFiles(client, realDebridTorrentId);
        torrentInfo = await _getTorrentInfo(client, realDebridTorrentId);
      }

      final status = torrentInfo["status"]?.toString();
      final links =
          (torrentInfo["links"] as List?)?.cast<dynamic>() ?? const [];

      if (status == "downloaded" && links.isNotEmpty) {
        final unrestricted =
            await _unrestrictLink(client, links.first.toString());
        final download = unrestricted["download"]?.toString();

        if (download == null || download.isEmpty) {
          throw Exception("Real-Debrid did not return a download URL.");
        }

        return Uri.decodeComponent(download);
      }

      throw DebriderIsProcessingException(
        "status: ${status ?? "unknown"}",
      );
    }

    final unrestricted = await _unrestrictLink(client, uri);
    final download = unrestricted["download"]?.toString();

    if (download == null || download.isEmpty) {
      throw Exception("Real-Debrid did not return a download URL.");
    }

    return Uri.decodeComponent(download);
  }

  Future<Map<String, dynamic>> _addMagnet(Dio client, String magnet) async {
    final response = await client.post<Map<String, dynamic>>(
      "/torrents/addMagnet",
      data: {"magnet": magnet},
    );

    return _requireDataMap(
        response.data, "Failed to add magnet to Real-Debrid.");
  }

  Future<Map<String, dynamic>> _getTorrentInfo(Dio client, String id) async {
    final response =
        await client.get<Map<String, dynamic>>("/torrents/info/$id");

    return _requireDataMap(
      response.data,
      "Failed to fetch Real-Debrid torrent info.",
    );
  }

  Future<void> _selectAllFiles(Dio client, String id) async {
    await client.post<void>(
      "/torrents/selectFiles/$id",
      data: {"files": "all"},
    );
  }

  Future<Map<String, dynamic>> _unrestrictLink(Dio client, String link) async {
    final response = await client.post<Map<String, dynamic>>(
      "/unrestrict/link",
      data: {"link": link},
    );

    return _requireDataMap(
      response.data,
      "Failed to unrestrict the Real-Debrid link.",
    );
  }

  Future<List<Map<String, dynamic>>> _getAllTorrentsFromUser(Dio client) async {
    final response = await client.get<List<dynamic>>("/torrents");
    final items = response.data ?? const [];

    return items.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item.cast<String, dynamic>());
    }).toList();
  }

  Future<String> _getTorrentId(Dio client, String magnetUri) async {
    final userTorrents = await _getAllTorrentsFromUser(client);
    final infoHash = TorrentHelper.extractInfoHash(magnetUri);

    final existingTorrent = userTorrents.firstWhere(
      (userTorrent) =>
          userTorrent["hash"]?.toString().toLowerCase() == infoHash,
      orElse: () => const {},
    );

    final existingId = existingTorrent["id"]?.toString();
    if (existingId != null && existingId.isNotEmpty) {
      return existingId;
    }

    final torrent = await _addMagnet(client, magnetUri);
    final torrentId = torrent["id"]?.toString();

    if (torrentId == null || torrentId.isEmpty) {
      throw Exception("Real-Debrid did not return a torrent id.");
    }

    return torrentId;
  }

  Map<String, dynamic> _requireDataMap(
    Map<String, dynamic>? data,
    String fallbackMessage,
  ) {
    if (data != null) {
      final error = data["error"]?.toString();
      if (error != null && error.isNotEmpty) {
        throw Exception(error);
      }
      return data;
    }

    throw Exception(fallbackMessage);
  }

  String _formatDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (data is Map && data["error"] != null) {
      return data["error"].toString();
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    if (statusCode != null) {
      return "Real-Debrid request failed with status $statusCode.";
    }

    return error.message ?? "Unknown Real-Debrid error.";
  }
}
