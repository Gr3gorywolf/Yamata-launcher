import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/repository/platform_catalog_sources_repository.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/models/platform_catalog_source.dart';

class WebSourcesManagerService {
  HttpServer? _server;
  int port = 8080;

  Future<String> _getHtmlFile() async {
    final html = await rootBundle.loadString('assets/web/sources_manager.html');
    return html;
  }

  Future<String> start() async {
    final address = InternetAddress.anyIPv4;
    _server = await HttpServer.bind(address, port);

    _server!.listen(_handleRequest);

    final ip = await _getLocalIp();
    return 'http://$ip:$port';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }

  Future<String> _getLocalIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return 'localhost';
  }

  void _handleRequest(HttpRequest request) async {
    final path = request.uri.path;

    if (path == '/') {
      await _serveHtml(request);
      return;
    }

    if (path.startsWith('/api/download-sources')) {
      await _handleDownloadSources(request);
      return;
    }

    if (path.startsWith('/api/platform-catalogs')) {
      await _handlePlatformCatalogs(request);
      return;
    }

    request.response
      ..statusCode = HttpStatus.notFound
      ..close();
  }

  Future<void> _serveHtml(HttpRequest request) async {
    request.response
      ..headers.contentType = ContentType.html
      ..write(await _getHtmlFile())
      ..close();
  }

  Future<void> _handleAddOrUpdateDownloadSource(
      String url, DownloadSourceType type) async {
    final source =
        await DownloadSourcesRepository().fetchDownloadSource(url, type);

    if (source == null) {
      throw Exception(
          "Failed to fetch download source, please check the URL and try again.");
    }

    source.sourceInfo.downloadUrl = url;
    source.sourceInfo.type = type;
    var provider = await Provider.of<DownloadSourcesProvider>(navigatorContext!,
        listen: false);
    var success = await provider.setDownloadSource(source);
    if (!success) {
      throw Exception("This source already exists.");
    }
  }

  Future<void> _handleAddOrUpdatePlatformCatalogSource(
      String url, bool isUpdating) async {
    final source = await ConsoleSourcesRepository().fetchSource(url);
    if (source == null) {
      throw Exception(
          "Failed to fetch platform catalog source, please check the URL and try again.");
    }
    source.downloadUrl = url;
    var validationError = ConsoleService.validatePlatformCatalogSource(source);
    if (validationError != null) {
      throw Exception(validationError);
    }
    if (isUpdating) {
      bool updated = await ConsoleService.updateConsoleSource(source);
      if (!updated) {
        throw Exception("This source doesn't exist.");
      }
      return;
    }
    var added = await ConsoleService.addConsoleSource(source);
    if (!added) {
      throw Exception("This source already exists.");
    }
  }

  // ================= DOWNLOAD SOURCES =================

  Future<void> _handleDownloadSources(HttpRequest req) async {
    if (req.method == 'GET') {
      final sources =
          Provider.of<DownloadSourcesProvider>(navigatorContext!, listen: false)
              .downloadSources;

      final data = sources
          .map((e) => {
                'id': e.sourceInfo!.downloadUrl,
                'title': e.sourceInfo!.title,
                'type': e.sourceInfo!.type?.name,
                'games': e.downloads!.length,
              })
          .toList();

      _json(req, data);
      return;
    }

    if (req.method == 'POST') {
      final body = await utf8.decoder.bind(req).join();
      final jsonBody = jsonDecode(body);

      final url = jsonBody['url'];
      final type = DownloadSourceType.values
          .firstWhere((e) => e.name == jsonBody['type']);
      try {
        await _handleAddOrUpdateDownloadSource(url, type);
      } catch (e) {
        _json(req, {'ok': false, 'error': e.toString()},
            statusCode: HttpStatus.internalServerError);
        return;
      }
      _json(req, {'ok': true});
      return;
    }

    if (req.method == 'DELETE') {
      final id = utf8.decode(base64Decode(req.uri.queryParameters['id']!));
      final provider = Provider.of<DownloadSourcesProvider>(navigatorContext!,
          listen: false);
      final source = provider.downloadSources
          .firstWhere((e) => e.sourceInfo!.downloadUrl == id);
      provider.removeDownloadSource(source);
      _json(req, {'ok': true});
      return;
    }

    if (req.method == 'PUT') {
      final id = utf8.decode(base64Decode(req.uri.queryParameters['id']!));
      var foundSource =
          Provider.of<DownloadSourcesProvider>(navigatorContext!, listen: false)
              .downloadSources
              .firstWhereOrNull((e) => e.sourceInfo!.downloadUrl == id);
      try {
        if (foundSource == null) {
          throw Exception("This source type does not support refreshing.");
        }
        await _handleAddOrUpdateDownloadSource(
            foundSource.sourceInfo.downloadUrl!, foundSource.sourceInfo.type!);
      } catch (e) {
        _json(req, {'ok': false, 'error': e.toString()},
            statusCode: HttpStatus.internalServerError);
        return;
      }
      _json(req, {'ok': true});
      return;
    }
  }

  // ================= PLATFORM CATALOGS =================

  Future<void> _handlePlatformCatalogs(HttpRequest req) async {
    if (req.method == 'GET') {
      final data = ConsoleService.externalPlatformCatalogs
          .map((e) => {
                'id': e.downloadUrl,
                'name': e.sourceName,
                'platform': e.console.name
              })
          .toList();

      _json(req, data);
      return;
    }

    if (req.method == 'POST') {
      final body = await utf8.decoder.bind(req).join();
      final jsonBody = jsonDecode(body);

      final url = jsonBody['url'];
      try {
        await _handleAddOrUpdatePlatformCatalogSource(url, false);
      } catch (e) {
        _json(req, {'ok': false, 'error': e.toString()},
            statusCode: HttpStatus.internalServerError);
        return;
      }
      _json(req, {'ok': true});
      return;
    }

    if (req.method == 'DELETE') {
      final id = utf8.decode(base64Decode(req.uri.queryParameters['id']!));
      final source = ConsoleService.externalPlatformCatalogs
          .firstWhere((e) => e.downloadUrl == id);
      ConsoleService.deleteConsoleSource(source);
      _json(req, {'ok': true});
      return;
    }

    if (req.method == 'PUT') {
      final id = utf8.decode(base64Decode(req.uri.queryParameters['id']!));

      try {
        await _handleAddOrUpdatePlatformCatalogSource(id, true);
      } catch (e) {
        _json(req, {'ok': false, 'error': e.toString()},
            statusCode: HttpStatus.internalServerError);
        return;
      }
      _json(req, {'ok': true});
      return;
    }
  }

  void _json(HttpRequest req, Object data, {int statusCode = HttpStatus.ok}) {
    req.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(data))
      ..close();
  }
}
