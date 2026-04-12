import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:yamata_launcher/models/contracts/credential_storage.dart';

class SecureCredentialStorage implements CredentialStorage {
  final FlutterSecureStorage _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.unlocked,
      useDataProtectionKeyChain: false,
    ),
  );

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
