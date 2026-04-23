import 'dart:convert';

import 'package:yamata_launcher/models/contracts/credential_storage.dart';
import 'package:yamata_launcher/models/contracts/debrider.dart';
import 'package:yamata_launcher/models/debrider_credentials.dart';
import 'package:yamata_launcher/services/debriders/alldebrid_debrider.dart';
import 'package:yamata_launcher/services/debriders/realdebrid_debrider.dart';
import 'package:yamata_launcher/services/debriders/torbox_debrider.dart';
import 'package:yamata_launcher/utils/credentials_storage/hybrid_credentials_storage.dart';

class CredentialsService {
  static CredentialStorage? _credentialStorage = HybridStorage();
  static CredentialStorage get _storage {
    if (_credentialStorage == null) {
      _credentialStorage = HybridStorage();
    }
    return _credentialStorage!;
  }

  static Future<bool> saveCredentials(String key, String creds) async {
    try {
      await _storage.write("creds_$key", creds);
      return true;
    } catch (e) {
      print("Error saving credentials for $key: $e");
      return false;
    }
  }

  static Future<String?> getCredentials(String key) async {
    try {
      String? jsonString = await _storage.read("creds_$key");
      if (jsonString == null) return null;
      return jsonString;
    } catch (e) {
      print("Error retrieving credentials for $key: $e");
      return null;
    }
  }

  static Future<void> removeCredentials(String key) async {
    try {
      await _storage.delete("creds_$key");
    } catch (e) {
      print("Error deleting credentials for $key: $e");
      return;
    }
  }
}
