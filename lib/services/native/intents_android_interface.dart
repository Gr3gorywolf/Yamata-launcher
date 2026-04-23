import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/providers/app_provider.dart';

class IntentsAndroidInterface {
  static const _channel = MethodChannel('yamata.launcher/methods');
  static String aria2cPath = "";
  static String certPath = "";

  static init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'newIntent') {
        Provider.of<AppProvider>(navigatorContext!, listen: false)
            .setIncomingDownloadUrl(call.arguments);
      }
    });
  }

  static Future<bool?> grantUriPermission(
      String uri, String packageName) async {
    var result = await _channel.invokeMethod<bool>(
        'grantUriPermission', {'uri': uri, 'packageName': packageName});
    print("Intent URI: $result");
    return result;
  }

  static Future<String?> getIntentUri(String filePath) async {
    var result = await _channel
        .invokeMethod<String>('getIntentUriFromFile', {'path': filePath});
    print("Intent URI: $result");
    return result;
  }

  static Future<String?> getIncomingIntentUrl() async {
    try {
      var result = await _channel.invokeMethod('getIncomingIntentUrl');
      return result;
    } on PlatformException catch (e) {
      throw Exception("Failed to get incoming intent URL");
    }
  }
}
