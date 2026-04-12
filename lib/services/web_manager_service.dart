import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/models/debrider_credentials.dart';
import 'package:yamata_launcher/models/site_cookies.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/console_service.dart';
import 'package:yamata_launcher/services/debrider_service.dart';
import 'package:yamata_launcher/repository/platform_catalog_sources_repository.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/models/platform_catalog_source.dart';
import 'package:yamata_launcher/services/cookies_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/utils/http_helper.dart';
import 'package:yamata_launcher/utils/url_helper.dart';

class WebManagerService {
  HttpServer? _server;
  int port = 8487;

  Future<String> _getHtmlFile() async {
    var data = {
      "downloadSourceTypes":
          DownloadSourceType.values.map((e) => e.name).toList(),
    };
    final html = await rootBundle.loadString('assets/web/web_manager.html');
    return html.replaceAll("{{data}}", jsonEncode(data));
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

    if (path.startsWith('/api/cookies')) {
      await _handleCookies(request);
      return;
    }

    if (path.startsWith('/api/debriders')) {
      await _handleDebriders(request);
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

  // ================= Cookie management =================
  Future<void> _handleCookies(HttpRequest req) async {
    if (req.method == 'GET') {
      var cookieSites = await CookiesService().getAllCookieSiteUrls();
      var sources = await Future.wait(cookieSites.map((site) async {
        var cookies = await CookiesService().getSiteCookies(site);
        return {
          'site': site,
          'cookies': cookies?.cookie,
          'headers': cookies?.headers,
        };
      }));
      final data = sources
          .map((e) => {
                'site': e['site'],
                'cookies': e['cookies'],
                'headers': e['headers'],
              })
          .toList();

      _json(req, data);
      return;
    }

    if (req.method == 'PUT') {
      var cookieSites = await CookiesService().getAllCookieSiteUrls();
      final body = await utf8.decoder.bind(req).join();
      final jsonBody = jsonDecode(body);
      final site = UrlHelper.getSiteFromUrl(jsonBody['site']);
      final cookies = jsonBody['cookies'];
      final headers = jsonBody['headers'];
      if (site.trim().isEmpty) {
        _json(req, {'ok': false, 'error': 'Site URL cannot be empty.'},
            statusCode: HttpStatus.badRequest);
        return;
      }
      var exists = cookieSites.contains(site);
      var success = await CookiesService().saveSiteCookies(
        site,
        SiteCookies(
          cookie: cookies,
          headers: headers,
        ),
      );

      if (!success) {
        _json(
            req,
            {
              'ok': false,
              'error':
                  'Failed to save site cookies. Check the logs for more details.'
            },
            statusCode: HttpStatus.internalServerError);
        return;
      }

      if (!exists) {
        cookieSites.add(site);
        await SettingsService().set(
          SettingsKeys.COOKIE_SITE_URLS,
          jsonEncode(cookieSites),
        );
      }
      _json(req, {'ok': true});
      return;
    }

    if (req.method == 'DELETE') {
      var site = utf8.decode(base64Decode(req.uri.queryParameters['site']!));
      site = UrlHelper.getSiteFromUrl(site);
      var cookieSites = await CookiesService().getAllCookieSiteUrls();
      if (site == null || site.trim().isEmpty) {
        _json(req, {'ok': false, 'error': 'Site URL cannot be empty.'},
            statusCode: HttpStatus.badRequest);
        return;
      }

      cookieSites.remove(site.trim());
      await SettingsService()
          .set(SettingsKeys.COOKIE_SITE_URLS, jsonEncode(cookieSites));
      await CookiesService().removeSiteCookies(site.trim());
      _json(req, {'ok': true});
      return;
    }
  }

  // ================= Debrider management =================
  Future<void> _handleDebriders(HttpRequest req) async {
    if (req.method == 'GET') {
      final providers = await Future.wait(
        DebriderService.debriders.map((debrider) async {
          final credentials =
              await DebriderService.getDebriderCredentials(debrider);
          final apiKey = credentials?.apiKey ?? "";

          return {
            'name': debrider.name,
            'settingKey': debrider.settingKey,
            'apiKey': apiKey,
            'configured': apiKey.trim().isNotEmpty,
            'authenticated': await debrider.isAuthenticated(),
          };
        }),
      );

      _json(req, providers);
      return;
    }

    if (req.method == 'PUT') {
      final body = await utf8.decoder.bind(req).join();
      final jsonBody = jsonDecode(body);
      final settingKey = jsonBody['settingKey']?.toString().trim() ?? "";
      final apiKey = jsonBody['apiKey']?.toString().trim() ?? "";

      if (settingKey.isEmpty) {
        _json(req, {'ok': false, 'error': 'Debrid provider is required.'},
            statusCode: HttpStatus.badRequest);
        return;
      }

      if (apiKey.isEmpty) {
        _json(req, {'ok': false, 'error': 'API key cannot be empty.'},
            statusCode: HttpStatus.badRequest);
        return;
      }

      final debrider = DebriderService.debriders
          .firstWhereOrNull((item) => item.settingKey == settingKey);

      if (debrider == null) {
        _json(req, {'ok': false, 'error': 'Debrid provider not found.'},
            statusCode: HttpStatus.notFound);
        return;
      }

      final success = await DebriderService.saveDebriderCredentials(
        debrider,
        DebriderCredentials(apiKey: apiKey),
      );

      if (!success) {
        _json(
            req,
            {
              'ok': false,
              'error':
                  'Failed to save debrid credentials. Check the logs for more details.'
            },
            statusCode: HttpStatus.internalServerError);
        return;
      }

      _json(req, {'ok': true});
      return;
    }

    if (req.method == 'DELETE') {
      final encodedSettingKey = req.uri.queryParameters['settingKey'];
      final settingKey = encodedSettingKey == null
          ? ""
          : utf8.decode(base64Decode(encodedSettingKey)).trim();

      if (settingKey.isEmpty) {
        _json(req, {'ok': false, 'error': 'Debrid provider is required.'},
            statusCode: HttpStatus.badRequest);
        return;
      }

      final debrider = DebriderService.debriders
          .firstWhereOrNull((item) => item.settingKey == settingKey);

      if (debrider == null) {
        _json(req, {'ok': false, 'error': 'Debrid provider not found.'},
            statusCode: HttpStatus.notFound);
        return;
      }

      await DebriderService.removeDebriderCredentials(debrider);
      _json(req, {'ok': true});
      return;
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
