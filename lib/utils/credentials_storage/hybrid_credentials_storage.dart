import 'package:yamata_launcher/models/contracts/credential_storage.dart';
import 'package:yamata_launcher/utils/credentials_storage/encrypted_credentials_storage.dart';
import 'package:yamata_launcher/utils/credentials_storage/secure_credential_storage.dart';

class HybridStorage implements CredentialStorage {
  CredentialStorage? _storage;
  Future<void>? _initialization;

  Future<void> _init() async {
    if (_storage != null) return;
    if (_initialization != null) {
      await _initialization;
      return;
    }

    _initialization = () async {
      try {
        final secure = SecureCredentialStorage();
        await secure.write("__test__", "ok");
        await secure.delete("__test__");
        _storage = secure;
      } catch (_) {
        print("Secure storage not available, using file storage");
        _storage = EncryptedCredentialsStorage();
      }
    }();

    try {
      await _initialization;
    } finally {
      _initialization = null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    await _init();
    await _storage!.write(key, value);
  }

  @override
  Future<String?> read(String key) async {
    await _init();
    return await _storage!.read(key);
  }

  @override
  Future<void> delete(String key) async {
    await _init();
    await _storage!.delete(key);
  }
}
