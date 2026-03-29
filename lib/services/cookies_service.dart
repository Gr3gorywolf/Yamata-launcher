import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/models/site_cookies.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/utils/string_helper.dart';

class CookiesService {
  FlutterSecureStorage _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(
        accessibility: KeychainAccessibility.unlocked,
        useDataProtectionKeyChain: false),
  );
  Future<bool> saveSiteCookies(String site, SiteCookies cookies) async {
    try {
      await _storage.write(
          key: "cookies_${StringHelper.hash20(site)}",
          value: jsonEncode(cookies.toJson()));
      return true;
    } catch (e) {
      print("Error saving cookies for site $site: $e");
      return false;
    }
  }

  Future<List<String>> getAllCookieSiteUrls() async {
    String sitesArray =
        await SettingsService().get<String>(SettingsKeys.COOKIE_SITE_URLS);
    return List<String>.from(jsonDecode(sitesArray ?? "[]"));
  }

  Future<SiteCookies?> getSiteCookies(String site) async {
    try {
      String? jsonString =
          await _storage.read(key: "cookies_${StringHelper.hash20(site)}");
      if (jsonString == null) return null;
      return SiteCookies.fromJson(jsonDecode(jsonString));
    } catch (e) {
      print("Error retrieving cookies for site $site: $e");
      return null;
    }
  }

  Future<void> removeSiteCookies(String site) async {
    try {
      await _storage.delete(key: "cookies_${StringHelper.hash20(site)}");
    } catch (e) {
      print("Error deleting cookies for site $site: $e");
      return;
    }
  }
}
