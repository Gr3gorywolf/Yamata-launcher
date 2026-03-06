import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:yamata_launcher/models/platform_catalog_source.dart';

class ConsoleSourcesRepository {
  Future<PlatformCatalogSource?> fetchSource(String sourceUrl) async {
    var client = new http.Client();
    try {
      var res =
          await client.get(Uri.parse(sourceUrl)).timeout(Duration(seconds: 15));
      if (res.statusCode == 200) {
        var responseData = json.decode(res.body);
        return PlatformCatalogSource.fromJson(responseData);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
