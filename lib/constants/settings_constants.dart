import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:yamata_launcher/models/setting.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/ui/widgets/rom_list_item.dart';

enum SettingsKeys {
  DOWNLOAD_PATH,
  PREFIX_CONSOLE_SLUG,
  MOVE_ROMS_TO_NAMED_SUBFOLDER,
  ENABLE_IMAGE_CACHING,
  ENABLE_NOTIFICATIONS,
  ENABLE_EXTRACTION,
  MAX_CONCURRENT_EXTRACTIONS,
  DARK_MODE_ENABLED,
  CLOSE_TO_SYSTEM_TRAY,
  ANDROID_NOTIFICATIONS_TAGS,
  USE_BUILT_IN_LINK_EXTRACTOR,
  SHOW_MANUAL_INTERACTION_HINT,
  COOKIE_SITE_URLS,
  ROM_LIST_ITEM_TYPE,
  SHOW_CONTROLLER_GUIDE
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
  SettingsKeys.ANDROID_NOTIFICATIONS_TAGS: Setting<String>(
    key: 'android_notifications_tags',
    type: SettingType.string,
    defaultValue: "{}",
  ),
  SettingsKeys.USE_BUILT_IN_LINK_EXTRACTOR: Setting<bool>(
    key: 'use_built_in_link_extractor',
    type: SettingType.bool,
    defaultValue: true,
  ),
  SettingsKeys.SHOW_MANUAL_INTERACTION_HINT: Setting<bool>(
    key: 'show_manual_interaction_hint',
    type: SettingType.bool,
    defaultValue: true,
  ),
  SettingsKeys.COOKIE_SITE_URLS: Setting<String>(
    key: 'cookie_site_urls',
    type: SettingType.string,
    defaultValue: "[]",
  ),
  SettingsKeys.ROM_LIST_ITEM_TYPE: Setting<String>(
    key: 'rom_list_item_type',
    type: SettingType.string,
    defaultValue: Platform.isAndroid
        ? RomListItemType.listItem.name
        : RomListItemType.card.name,
  ),
  SettingsKeys.SHOW_CONTROLLER_GUIDE: Setting<bool>(
    key: 'show_controller_guide',
    type: SettingType.bool,
    defaultValue: true,
  ),
};
