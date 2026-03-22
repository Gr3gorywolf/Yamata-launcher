import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:yamata_launcher/models/site_cookies.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class CookiesService {
  Future<void> saveSiteCookies(String site, SiteCookies cookies) async {
    final storage = FlutterSecureStorage();
    await storage.write(
        key: "cookies_${StringHelper.hash20(site)}",
        value: jsonEncode(cookies.toJson()));
  }

  Future<SiteCookies?> getSiteCookies(String site) async {
    final storage = FlutterSecureStorage();
    String? jsonString =
        await storage.read(key: "cookies_${StringHelper.hash20(site)}");
    if (jsonString == null) return null;
    return SiteCookies.fromJson(jsonDecode(jsonString));
  }

  Future<void> removeSiteCookies(String site) async {
    final storage = FlutterSecureStorage();
    await storage.delete(key: "cookies_${StringHelper.hash20(site)}");
  }
}
