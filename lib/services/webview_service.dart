import 'package:adblocker_webview/adblocker_webview.dart';
import 'package:flutter/services.dart';

class WebviewService {
  static AdblockFilterManager _adBlockManager = AdblockFilterManager();
  static AdblockFilterManager get adBlockManager => _adBlockManager;
  static List<ResourceRule> _blockingRules = [];
  static List<ResourceRule> get blockingRules => _blockingRules;
  static init() async {
    var blocklist = await rootBundle.loadString("assets/web/blocklist.txt");
    await _adBlockManager.init(FilterConfig(
        filterTypes: [
          FilterType.easyList,
          FilterType.adGuard,
        ],
        blockedDomains:
            blocklist.split("\n").where((line) => line.isNotEmpty).toList()));
    blockingRules.addAll(_adBlockManager.getAllResourceRules());
  }
}
