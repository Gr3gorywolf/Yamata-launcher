import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/platform_catalog_source.dart';
import 'package:yamata_launcher/models/download_source.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/services/files_system_service.dart';

class ConsoleSourcesRepository {
  Future<PlatformCatalogSource?> fetchSource(String sourceUrl) async {
    var client = new http.Client();
    try {
      var res =
          await client.get(Uri.parse(sourceUrl)).timeout(Duration(seconds: 15));
      if (res.statusCode == 200) {
        final decoded = utf8.decode(res.bodyBytes);
        var responseData = json.decode(decoded);
        return PlatformCatalogSource.fromJson(responseData);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
