import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:path/path.dart' as p;

class SystemHelpers {
  static bool get isArm {
    return Platform.version.toLowerCase().contains("arm") ||
        Platform.version.toLowerCase().contains("aarch64");
  }

  static String get aria2cOutputBinary {
    var binary = "aria2c";
    if (Platform.isWindows) {
      binary = "aria2c.exe";
    }
    return binary;
  }

  static Future androidShareWithChooser(String text) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.SEND',
      type: 'text/plain',
      arguments: {
        'android.intent.extra.TEXT': text,
      },
    );

    await intent.launch();
  }

  /**
   * Resolves the executable path inside a macOS .app bundle.
   */
  static Future<String> resolveMacAppExecutable(String appPath) async {
    if (!appPath.endsWith('.app')) {
      return appPath;
    }

    final macOSDir = Directory(p.join(appPath, 'Contents', 'MacOS'));
    if (!await macOSDir.exists()) {
      throw StateError(
          'Invalid macOS app bundle (missing Contents/MacOS): $appPath');
    }

    final candidates = await macOSDir
        .list(followLinks: false)
        .where((e) => e is File)
        .cast<File>()
        .toList();

    if (candidates.isEmpty) {
      throw StateError('No executable found inside: ${macOSDir.path}');
    }

    return candidates.first.path;
  }

  static String getFileExtension(String fileName) {
    return fileName.split('.').last;
  }

  static String get aria2cAssetBinary {
    var aria2cBinary = "aria2c";
    if (Platform.isWindows) {
      aria2cBinary = "aria2c.exe";
    } else if (Platform.isMacOS) {
      aria2cBinary = "aria2c-macos-${isArm ? 'arm' : 'x86'}";
    } else if (Platform.isLinux) {
      aria2cBinary = "aria2c-linux-${isArm ? 'arm' : 'x86'}";
    } else if (Platform.isAndroid) {
      aria2cBinary = "aria2c-android";
    }
    return aria2cBinary;
  }

  static String get SevenZipOutputBinary {
    var sevenZipBinary = "7z";
    if (Platform.isWindows) {
      sevenZipBinary = "7z.exe";
    }
    return sevenZipBinary;
  }

  static String get SevenZipAssetBinary {
    var sevenZipBinary = "7z";
    if (Platform.isWindows) {
      sevenZipBinary = "7z.exe";
    } else if (Platform.isMacOS) {
      sevenZipBinary = "7z-macos";
    } else if (Platform.isLinux) {
      sevenZipBinary = "7z-linux-${isArm ? 'arm' : 'x86'}";
    }
    return sevenZipBinary;
  }

  static Future<List<String>> getAvailableDrives() async {
    List<String> drives = [];
    if (Platform.isWindows) {
      for (var letterCode = 65; letterCode <= 90; letterCode++) {
        final letter = String.fromCharCode(letterCode);
        final path = '$letter:\\';

        final dir = Directory(path);
        try {
          if (await dir.exists()) {
            drives.add(path);
          }
        } catch (e) {
          print('Error checking drive $path: $e');
        }
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      var rootDrive = "/";
      final possibleDirs = [
        '/mnt',
        '/media',
        '/Volumes',
      ];

      for (final base in possibleDirs) {
        final dir = Directory(base);
        if (await dir.exists()) {
          final entities = dir.listSync();
          for (final e in entities) {
            if (e is Directory) {
              drives.add(e.path);
            }
          }
        }
      }
    }
    return drives;
  }
}
