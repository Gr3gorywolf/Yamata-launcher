import 'dart:io';

import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:http/http.dart' as http;

class EmulatorIntentsRepository {
  Future<bool> updateEmulatorIntentsFile() async {
    var baseUrl = "${AppConstants.apiBasePath}/Configs/EmulatorIntents.json";
    var client = new http.Client();
    try {
      var res = await client.get(Uri.parse(baseUrl));
      if (res.statusCode == 200) {
        var consoleIntentsFile =
            File(FileSystemService.emulatorIntentsFilePath);
        await consoleIntentsFile.writeAsString(res.body);
        return true;
      }
    } catch (e) {}

    return false;
  }
}
