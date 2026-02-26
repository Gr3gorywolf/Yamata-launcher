import 'dart:io';

import 'package:flutter/services.dart';

class DownloadForegroundServiceAndroidInterface {
  static const _channel = MethodChannel('yamata.launcher/methods');
  static bool _isServiceRunning = false;

  static Future<void> startService() async {
    if (Platform.isAndroid && !_isServiceRunning) {
      await _channel.invokeMethod('startDownloadService');
      _isServiceRunning = true;
    }
  }

  static Future<void> stopService() async {
    if (Platform.isAndroid && _isServiceRunning) {
      await _channel.invokeMethod('stopDownloadService');
      _isServiceRunning = false;
    }
  }
}
