import 'dart:convert';

import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/models/update_info.dart';
import 'package:http/http.dart' as http;
import 'package:yamata_launcher/services/update_service.dart';

class UpdateRepository {
  Future<UpdateInfo?> fetchUpdateInfo() async {
    final url =
        "https://api.github.com/repos/${AppConstants.repositoryBasePath}/releases/latest";
    var client = new http.Client();
    var fileToSearch = UpdateService.getUpdateFileName();
    if (fileToSearch == null) return null;
    try {
      var res = await client.get(Uri.parse(url)).timeout(Duration(seconds: 15));
      if (res.statusCode == 200) {
        var json = jsonDecode(res.body);
        String? downloadUrl;
        for (var asset in json['assets']) {
          if (asset['name'] == fileToSearch) {
            downloadUrl = asset['browser_download_url'];
            break;
          }
        }
        if (downloadUrl == null) return null;
        return UpdateInfo(
          version: (json['tag_name'] ?? "").toString().replaceFirst("v", ""),
          changelog: json['body'] ?? "",
          fileToDownload: downloadUrl,
        );
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
