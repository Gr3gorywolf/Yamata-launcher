import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/models/update_info.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/ui/widgets/view_mode_toggle.dart';
import 'package:provider/provider.dart';

class AppProvider extends ChangeNotifier {
  static AppProvider of(BuildContext ctx) {
    return Provider.of<AppProvider>(ctx);
  }

  bool _isUsingGamepad = false;
  bool _isAppLoaded = false;
  bool _showGamepadGuide = true;
  String? _incomingDownloadUrl = null;
  bool _sortByLastPlayedByDefault = true;
  bool get isAppLoaded => _isAppLoaded;
  UpdateInfo? _updateInfo;
  ThemeMode _theme = ThemeMode.system;
  ThemeMode get themeMode => _theme;
  UpdateInfo? get updateInfo => _updateInfo;
  bool get isUsingGamepad => _isUsingGamepad;
  bool get showGamepadGuide => _showGamepadGuide;
  bool get sortByLastPlayedByDefault => _sortByLastPlayedByDefault;
  String? get incomingDownloadUrl => _incomingDownloadUrl;
  ViewModeToggleMode romListItemType = ViewModeToggleMode.grid;
  Map<String, String> _executionLogs = {};
  Map<String, String> get executionLogs => _executionLogs;
  StreamController<String?> onGamepadButtonPressed =
      StreamController<String?>.broadcast();
  StreamController<bool?> onChangeTab = StreamController<bool?>.broadcast();
  StreamController<String?> onUrlIncoming =
      StreamController<String?>.broadcast();
  setAppLoaded(bool val) {
    _isAppLoaded = val;
    syncSettings();
    SettingsService()
        .get<String>(SettingsKeys.ROM_LIST_ITEM_TYPE)
        .then((value) {
      if (value != null) {
        romListItemType = ViewModeToggleMode.values.firstWhere(
          (e) => e.name == value,
          orElse: () => Platform.isAndroid
              ? ViewModeToggleMode.list
              : ViewModeToggleMode.grid,
        );
      }
      SettingsService()
          .get<bool>(SettingsKeys.SHOW_CONTROLLER_GUIDE)
          .then((value) {
        if (value != null) {
          _showGamepadGuide = value;
        }
        notifyListeners();
      });

      notifyListeners();
    });
    notifyListeners();
  }

  syncSettings() async {
    _sortByLastPlayedByDefault = await SettingsService()
        .get<bool>(SettingsKeys.SORT_BY_LAST_PLAYED_BY_DEFAULT);
    notifyListeners();
  }

  setShowGamepadGuide(bool val) {
    _showGamepadGuide = val;
    notifyListeners();
  }

  addLogToExecutionLogs(String slug, String log) {
    var currentLogs = _executionLogs[slug] ?? "";
    currentLogs += log + "\n";
    _executionLogs[slug] = currentLogs;
    notifyListeners();
  }

  cleanExecutionLogs(String slug) {
    _executionLogs.remove(slug);
    notifyListeners();
  }

  setUpdateInfo(UpdateInfo info) {
    _updateInfo = info;
    notifyListeners();
  }

  setUsingGamepad(bool val) {
    _isUsingGamepad = val;
    notifyListeners();
  }

  setConsoleRomsItemType(ViewModeToggleMode type) {
    romListItemType = type;
    SettingsService().set<String>(SettingsKeys.ROM_LIST_ITEM_TYPE, type.name);
    notifyListeners();
  }

  setIncomingDownloadUrl(String? url) {
    _incomingDownloadUrl = url;
    if (url != null && url.isNotEmpty) {
      onUrlIncoming.add(url);
    }
    notifyListeners();
  }

  setupTheme({bool? darkModeEnabled}) async {
    if (darkModeEnabled != null) {
      if (darkModeEnabled) {
        _theme = ThemeMode.dark;
      } else {
        _theme = ThemeMode.light;
      }
      notifyListeners();
      return;
    }
    await SettingsService()
        .get<bool>(SettingsKeys.DARK_MODE_ENABLED)
        .then((value) {
      if (value != null) {
        if (value) {
          _theme = ThemeMode.dark;
        } else {
          _theme = ThemeMode.light;
        }
      } else {
        _theme = ThemeMode.system;
      }
      notifyListeners();
    });
  }
}
