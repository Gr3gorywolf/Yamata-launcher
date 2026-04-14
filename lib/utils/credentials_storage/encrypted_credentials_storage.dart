import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:yamata_launcher/models/contracts/credential_storage.dart';
import 'package:yamata_launcher/services/files_system_service.dart';

class EncryptedCredentialsStorage implements CredentialStorage {
  static const _fileName = 'credentials.enc';
  static const _formatVersion = 1;

  final IV _legacyIv = IV.fromLength(16);

  late final Key _key;
  late final Encrypter _encrypter;
  late final Encrypter _legacyEncrypter;

  File? _file;
  Map<String, dynamic>? _cache;
  Future<void>? _initialization;
  Future<void> _operationQueue = Future.value();

  EncryptedCredentialsStorage() {
    _key = Key.fromUtf8(generateDeviceKey());
    _encrypter = Encrypter(AES(_key, mode: AESMode.cbc, padding: 'PKCS7'));
    _legacyEncrypter = Encrypter(AES(_key));
  }

  String generateDeviceKey() {
    final data = "${Platform.localHostname}-${Platform.operatingSystem}";
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 32);
  }

  Future<T> _runExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _operationQueue = _operationQueue.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  Future<void> _init() async {
    if (_file != null) return;
    if (_initialization != null) {
      await _initialization;
      return;
    }

    _initialization = () async {
      final rootPath =
          (FileSystemService.appDataFolderPath as String?)?.trim() ?? '';
      final basePath = rootPath.isNotEmpty ? rootPath : Directory.current.path;
      final baseDir = Directory(basePath);

      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final file = File("${baseDir.path}/$_fileName");
      _file = file;

      if (!await file.exists()) {
        await _persist({});
      }
    }();

    try {
      await _initialization;
    } finally {
      _initialization = null;
    }
  }

  Map<String, dynamic> _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw const FormatException('Credentials payload is not a JSON map');
  }

  String _encodePayload(Map<String, dynamic> data) {
    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(jsonEncode(data), iv: iv);

    return jsonEncode({
      'version': _formatVersion,
      'iv': iv.base64,
      'cipherText': encrypted.base64,
    });
  }

  Future<void> _writeRaw(String content) async {
    final file = _file!;
    final tempFile = File("${file.path}.tmp");
    final backupFile = File("${file.path}.bak");

    await tempFile.writeAsString(content, flush: true);

    if (await backupFile.exists()) {
      await backupFile.delete();
    }

    if (await file.exists()) {
      await file.rename(backupFile.path);
    }

    try {
      await tempFile.rename(file.path);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (_) {
      if (await backupFile.exists() && !await file.exists()) {
        await backupFile.rename(file.path);
      }
      rethrow;
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> _persist(Map<String, dynamic> data) async {
    final snapshot = Map<String, dynamic>.from(data);
    await _writeRaw(_encodePayload(snapshot));
    _cache = snapshot;
  }

  Map<String, dynamic>? _tryDecodeVersionedPayload(String rawContent) {
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map) return null;

    final payload = Map<String, dynamic>.from(decoded);
    final ivBase64 = payload['iv'];
    final cipherText = payload['cipherText'];

    if (ivBase64 is! String || cipherText is! String) {
      return null;
    }

    final decrypted = _encrypter.decrypt64(
      cipherText,
      iv: IV.fromBase64(ivBase64),
    );

    return _normalizeMap(jsonDecode(decrypted));
  }

  Map<String, dynamic>? _tryDecodeLegacyEncryptedPayload(String rawContent) {
    final decrypted = _legacyEncrypter.decrypt64(rawContent, iv: _legacyIv);
    return _normalizeMap(jsonDecode(decrypted));
  }

  Map<String, dynamic>? _tryDecodePlainJson(String rawContent) {
    return _normalizeMap(jsonDecode(rawContent));
  }

  Future<void> _backupCorruptedFile(String rawContent) async {
    final file = _file;
    if (file == null || rawContent.trim().isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupFile = File("${file.path}.corrupted.$timestamp");

    try {
      await backupFile.writeAsString(rawContent, flush: true);
    } catch (error) {
      print("Failed to backup corrupted credentials file: $error");
    }
  }

  Future<Map<String, dynamic>> _recoverStorage({
    required String rawContent,
    required Object error,
  }) async {
    print(
        "Recovering encrypted credentials storage after read failure: $error");
    await _backupCorruptedFile(rawContent);
    await _persist({});
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _loadAll() async {
    if (_cache != null) {
      return Map<String, dynamic>.from(_cache!);
    }

    final rawContent = (await _file!.readAsString()).trim();

    if (rawContent.isEmpty) {
      await _persist({});
      return <String, dynamic>{};
    }

    try {
      final versioned = _tryDecodeVersionedPayload(rawContent);
      if (versioned != null) {
        _cache = versioned;
        return Map<String, dynamic>.from(versioned);
      }
    } catch (error) {
      print("Failed to decode versioned credentials payload: $error");
    }

    try {
      final legacy = _tryDecodeLegacyEncryptedPayload(rawContent);
      if (legacy != null) {
        await _persist(legacy);
        return Map<String, dynamic>.from(legacy);
      }
    } catch (error) {
      print("Failed to decode legacy encrypted credentials payload: $error");
    }

    try {
      final plainJson = _tryDecodePlainJson(rawContent);
      if (plainJson != null) {
        await _persist(plainJson);
        return Map<String, dynamic>.from(plainJson);
      }
    } catch (error) {
      return _recoverStorage(rawContent: rawContent, error: error);
    }

    return _recoverStorage(
      rawContent: rawContent,
      error: const FormatException('Unsupported credentials payload format'),
    );
  }

  @override
  Future<void> write(String key, String value) {
    return _runExclusive(() async {
      await _init();
      final data = await _loadAll();
      data[key] = value;
      await _persist(data);
    });
  }

  @override
  Future<String?> read(String key) {
    return _runExclusive(() async {
      await _init();
      final data = await _loadAll();
      final value = data[key];
      return value is String ? value : value?.toString();
    });
  }

  @override
  Future<void> delete(String key) {
    return _runExclusive(() async {
      await _init();
      final data = await _loadAll();
      data.remove(key);
      await _persist(data);
    });
  }
}
