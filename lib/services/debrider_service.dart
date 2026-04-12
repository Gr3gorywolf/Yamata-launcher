import 'dart:convert';

import 'package:yamata_launcher/models/contracts/credential_storage.dart';
import 'package:yamata_launcher/models/contracts/debrider.dart';
import 'package:yamata_launcher/models/debrider_credentials.dart';
import 'package:yamata_launcher/services/debriders/alldebrid_debrider.dart';
import 'package:yamata_launcher/services/debriders/realdebrid_debrider.dart';
import 'package:yamata_launcher/services/debriders/torbox_debrider.dart';
import 'package:yamata_launcher/utils/credentials_storage/hybrid_credentials_storage.dart';

class DebriderService {
  static CredentialStorage? _credentialStorage = HybridStorage();
  static CredentialStorage get _storage {
    if (_credentialStorage == null) {
      _credentialStorage = HybridStorage();
    }
    return _credentialStorage!;
  }

  static final List<Debrider> debriders = [
    RealdebridDebrider(),
    TorboxDebrider(),
    AllDebridDebrider(),
  ];

  static Debrider? getDebriderForUrl(String url) {
    for (var debrider in debriders) {
      if (debrider.canHandleUrl(url)) {
        return debrider;
      }
    }
    return null;
  }

  static Future<bool> saveDebriderCredentials(
      Debrider debrider, DebriderCredentials apiKey) async {
    try {
      await _storage.write(
          "debriders_${debrider.settingKey}", jsonEncode(apiKey.toJson()));
      return true;
    } catch (e) {
      print("Error saving debrider credentials for ${debrider.name}: $e");
      return false;
    }
  }

  static Future<DebriderCredentials?> getDebriderCredentials(
      Debrider debrider) async {
    try {
      String? jsonString =
          await _storage.read("debriders_${debrider.settingKey}");
      if (jsonString == null) return null;
      return DebriderCredentials.fromJson(jsonDecode(jsonString));
    } catch (e) {
      print("Error retrieving debrider credentials for ${debrider.name}: $e");
      return null;
    }
  }

  static Future<void> removeDebriderCredentials(Debrider debrider) async {
    try {
      await _storage.delete("debriders_${debrider.settingKey}");
    } catch (e) {
      print("Error deleting debrider credentials for ${debrider.name}: $e");
      return;
    }
  }
}
