import 'package:flutter/services.dart';

class WakelockAndroidInterface {
  static const _channel = MethodChannel('yamata.launcher/methods');

  static bool? _currentValue = null;

  static Future<void> setWakeLock(bool shouldAcquire) async {
    if (_currentValue == shouldAcquire) return;
    _currentValue = shouldAcquire;
    try {
      await _channel
          .invokeMethod('setWakeLock', {'shouldAcquire': shouldAcquire});

      print("Wake lock set to: $shouldAcquire");
    } catch (e) {
      print("Error setting wakelock: $e");
    }
  }
}
