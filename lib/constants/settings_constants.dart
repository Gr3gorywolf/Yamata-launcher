import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:yamata_launcher/models/setting.dart';
import 'package:yamata_launcher/services/files_system_service.dart';

enum SettingsKeys {
  DOWNLOAD_PATH,
  PREFIX_CONSOLE_SLUG,
  MOVE_ROMS_TO_NAMED_SUBFOLDER,
  ENABLE_IMAGE_CACHING,
  ENABLE_NOTIFICATIONS,
  ENABLE_EXTRACTION,
  MAX_CONCURRENT_EXTRACTIONS,
  DARK_MODE_ENABLED,
  CLOSE_TO_SYSTEM_TRAY
}

final _systemIsDarkThemed =
    WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
Map<SettingsKeys, Setting> settingsRegistry = {
  SettingsKeys.DARK_MODE_ENABLED: Setting<bool>(
    key: 'dark_mode_enabled',
    type: SettingType.bool,
    defaultValue: _systemIsDarkThemed,
  ),
  SettingsKeys.DOWNLOAD_PATH: Setting<String>(
    key: 'download_path',
    type: SettingType.string,
    defaultValue: "",
  ),
  SettingsKeys.PREFIX_CONSOLE_SLUG: Setting<bool>(
    key: 'prefix_console_slug',
    type: SettingType.bool,
    defaultValue: false,
  ),
  SettingsKeys.ENABLE_IMAGE_CACHING: Setting<bool>(
    key: 'enable_image_caching',
    type: SettingType.bool,
    defaultValue: false,
  ),
  SettingsKeys.ENABLE_NOTIFICATIONS: Setting<bool>(
    key: 'enable_notifications',
    type: SettingType.bool,
    defaultValue: true,
  ),
  SettingsKeys.ENABLE_EXTRACTION: Setting<bool>(
    key: 'enable_extraction',
    type: SettingType.bool,
    defaultValue: true,
  ),
  SettingsKeys.MAX_CONCURRENT_EXTRACTIONS: Setting<int>(
    key: 'max_concurrent_extractions',
    type: SettingType.int,
    defaultValue: FileSystemService.isDesktop ? 4 : 2,
  ),
  SettingsKeys.CLOSE_TO_SYSTEM_TRAY: Setting<bool>(
    key: 'close_to_system_tray',
    type: SettingType.bool,
    defaultValue: true,
  ),
  SettingsKeys.MOVE_ROMS_TO_NAMED_SUBFOLDER: Setting<bool>(
    key: 'move_roms_to_named_subfolder',
    type: SettingType.bool,
    defaultValue: false,
  ),
};
