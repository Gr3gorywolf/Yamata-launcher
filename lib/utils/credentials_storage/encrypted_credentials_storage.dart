import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:yamata_launcher/models/contracts/credential_storage.dart';
import 'package:yamata_launcher/services/files_system_service.dart';

class EncryptedCredentialsStorage implements CredentialStorage {
  String generateDeviceKey() {
    final data = "${Platform.localHostname}-${Platform.operatingSystem}";
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 32); // 32 chars = 256 bits
  }

  File? _file;
  late Encrypter _encrypter;
  final _iv = IV.fromLength(16);
  Future<void>? _initialization;

  EncryptedCredentialsStorage() {
    final key = Key.fromUtf8(generateDeviceKey());
    _encrypter = Encrypter(AES(key));
  }

  Future<void> _init() async {
    if (_file != null) return;
    if (_initialization != null) {
      await _initialization;
      return;
    }

    _initialization = () async {
      final rootPath = (FileSystemService.rootPath as String?)?.trim() ?? "";
      final basePath = rootPath.isNotEmpty ? rootPath : Directory.current.path;

      final baseDir = Directory(basePath);
      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final file = File("${baseDir.path}/credentials.enc");

      if (!await file.exists()) {
        await file.writeAsString(_encrypt(jsonEncode({})));
      }

      _file = file;
    }();

    try {
      await _initialization;
    } finally {
      _initialization = null;
    }
  }

  String _encrypt(String plain) {
    return _encrypter.encrypt(plain, iv: _iv).base64;
  }

  String _decrypt(String encrypted) {
    return _encrypter.decrypt64(encrypted, iv: _iv);
  }

  Future<Map<String, dynamic>> _readAll() async {
    final content = await _file!.readAsString();
    final decrypted = _decrypt(content);
    return jsonDecode(decrypted);
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    final encrypted = _encrypt(jsonEncode(data));
    await _file!.writeAsString(encrypted);
  }

  @override
  Future<void> write(String key, String value) async {
    await _init();
    final data = await _readAll();
    data[key] = value;
    await _writeAll(data);
  }

  @override
  Future<String?> read(String key) async {
    await _init();
    final data = await _readAll();
    return data[key];
  }

  @override
  Future<void> delete(String key) async {
    await _init();
    final data = await _readAll();
    data.remove(key);
    await _writeAll(data);
  }
}
