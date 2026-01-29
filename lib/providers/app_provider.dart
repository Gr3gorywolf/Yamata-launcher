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

  bool _isAppLoaded = false;
  bool get isAppLoaded => _isAppLoaded;
  UpdateInfo? _updateInfo;
  ThemeMode _theme = ThemeMode.system;
  ThemeMode get themeMode => _theme;
  UpdateInfo? get updateInfo => _updateInfo;
  ViewModeToggleMode consoleRomsItemType = ViewModeToggleMode.grid;

  setAppLoaded(bool val) {
    _isAppLoaded = val;
    if (Platform.isAndroid) {
      consoleRomsItemType = ViewModeToggleMode.list;
    }
    notifyListeners();
  }

  setUpdateInfo(UpdateInfo info) {
    _updateInfo = info;
    notifyListeners();
  }

  setConsoleRomsItemType(ViewModeToggleMode type) {
    consoleRomsItemType = type;
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
