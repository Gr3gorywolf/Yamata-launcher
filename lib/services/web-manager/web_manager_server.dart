import 'dart:io';

import 'package:alfred/alfred.dart';
import 'package:yamata_launcher/services/web-manager/helpers/html_page_builder.dart';
import 'package:yamata_launcher/services/web-manager/helpers/network_helper.dart';
import 'package:yamata_launcher/services/web-manager/routes/cookies_routes.dart';
import 'package:yamata_launcher/services/web-manager/routes/debriders_routes.dart';
import 'package:yamata_launcher/services/web-manager/routes/download_sources_routes.dart';
import 'package:yamata_launcher/services/web-manager/routes/platform_catalogs_routes.dart';

class WebManagerServer {
  WebManagerServer({this.port = 8487});

  HttpServer? _server;
  final int port;

  Future<String> start() async {
    final app = Alfred();
    _registerRoutes(app);

    _server = await app.listen(port, InternetAddress.anyIPv4.address);

    final ip = await getLocalIpAddress();
    return 'http://$ip:$port';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void _registerRoutes(Alfred app) {
    app.get('/', (req, res) async {
      res.headers.contentType = ContentType.html;
      return buildWebManagerHtml();
    });

    registerCookieRoutes(app);
    registerDebriderRoutes(app);
    registerDownloadSourceRoutes(app);
    registerPlatformCatalogRoutes(app);
  }
}
