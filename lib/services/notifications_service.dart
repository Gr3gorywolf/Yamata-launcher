import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:windows_notification/notification_message.dart';
import 'package:windows_notification/windows_notification.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/providers/library_provider.dart';
import 'package:yamata_launcher/services/emulator_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';

enum AndroidNotificationsActionTypes { CancelDownload, PlayRomAction }

class NotificationsService {
  NotificationsService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Map<AndroidNotificationsActionTypes, AndroidNotificationAction>
      androidNotificationActions = {
    AndroidNotificationsActionTypes.CancelDownload: AndroidNotificationAction(
      AndroidNotificationsActionTypes.CancelDownload.name,
      'Cancel',
      showsUserInterface: true,
      cancelNotification: true,
    ),
    AndroidNotificationsActionTypes.PlayRomAction: AndroidNotificationAction(
      AndroidNotificationsActionTypes.PlayRomAction.name,
      'Play',
      showsUserInterface: true,
      cancelNotification: true,
    ),
  };

  static const String _channelId = 'yamata_launcher_channel';
  static const String _channelName = 'yamata_launcher Notifications';
  static const String _channelDescription = 'Notifications for Yamata Launcher';
  static final Map<String, int> _tagIds = {};
  static final Set<String> _ongoingTags = {};

  static void saveTags() {
    SettingsService()
        .set(SettingsKeys.ANDROID_NOTIFICATIONS_TAGS, jsonEncode(_tagIds));
  }

  static Future<void> loadTags() async {
    var savedTags = await SettingsService()
        .get<String>(SettingsKeys.ANDROID_NOTIFICATIONS_TAGS);
    if (savedTags.isNotEmpty) {
      var decoded = jsonDecode(savedTags);
      if (decoded is Map<String, dynamic>) {
        decoded.forEach((key, value) {
          if (value is int) {
            _tagIds[key] = value;
          }
        });
      }
    }
  }

  static void closeOngoingNotifications() {
    _ongoingTags.forEach((tag) {
      cancelNotificationByTag(tag);
    });
  }

  static void _onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) {
    var actionId = notificationResponse.actionId;
    if (actionId == AndroidNotificationsActionTypes.CancelDownload.name) {
      var downloadProvider =
          Provider.of<DownloadProvider>(navigatorContext!, listen: false);
      var downloadInfo =
          downloadProvider.getDownloadInfoBySlug(notificationResponse.payload);
      if (downloadInfo != null) {
        downloadProvider.abortDownload(downloadInfo);
      }
    }

    if (actionId == AndroidNotificationsActionTypes.PlayRomAction.name) {
      var libraryProvider =
          Provider.of<LibraryProvider>(navigatorContext!, listen: false);
      var libraryItem =
          libraryProvider.getLibraryItem(notificationResponse.payload ?? "");
      if (libraryItem == null) {
        return;
      }
      EmulatorService.openRom(libraryItem);
    }
  }

  static Future<String?> _getNotificationImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty || !imageUrl.startsWith("http")) {
      return imageUrl;
    }
    try {
      var uri = Uri.parse(imageUrl);
      var fileName = uri.pathSegments.last;
      var filePath = '${FileSystemService.notificationImagesPath}/$fileName';
      var file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }
      var httpClient = HttpClient();
      var request = await httpClient.getUrl(uri);
      var response = await request.close();
      if (response.statusCode == 200) {
        var bytes = await consolidateHttpClientResponseBytes(response);
        await file.writeAsBytes(bytes);
        return filePath;
      }
    } catch (e) {
      print(e);
    }
    return null;
  }

  static int getIdForTag(String tag) {
    var tagId = _tagIds.putIfAbsent(
        tag, () => DateTime.now().millisecondsSinceEpoch ~/ 1000);
    saveTags();
    return tagId;
  }

  static Future<void> init() async {
    var imagesDirectory = Directory(FileSystemService.notificationImagesPath);
    //clean old notification images
    if (imagesDirectory.existsSync()) {
      var files = imagesDirectory.listSync();
      for (var file in files) {
        try {
          var lastAccessed = await file.stat().then((stat) => stat.accessed);
          var difference = DateTime.now().difference(lastAccessed);
          if (difference.inHours > 10) {
            await file.delete();
          }
        } catch (e) {
          print(e);
        }
      }
    }

    if (Platform.isWindows) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const linuxInit =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    final settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
      linux: linuxInit,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    await loadTags();

    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification(
      {required String title,
      required String body,
      String? image,
      int? progressPercent,
      bool silent = false,
      String? tag,
      List<AndroidNotificationsActionTypes>? androidActions}) async {
    var notificationsEnabledSetting =
        await SettingsService().get<bool>(SettingsKeys.ENABLE_NOTIFICATIONS);
    if (notificationsEnabledSetting == false) {
      return;
    }
    if (image != null && image.isNotEmpty) {
      image = await _getNotificationImage(image);
      print("Notification image path: $image");
    }
    if (Platform.isWindows) {
      final _winNotifyPlugin =
          WindowsNotification(applicationId: "Yamata Launcher");
      NotificationMessage message = NotificationMessage.fromPluginTemplate(
          Random().nextInt(100000).toString(), title, body,
          image: image);
      _winNotifyPlugin.showNotificationPluginTemplate(message);
      return;
    }

    final androidDetails = await _androidDetails(
        image, progressPercent, tag, silent, body, androidActions);
    final darwinDetails = _darwinDetails(image);
    final linuxDetails = _linuxDetails(image);

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );
    var id = tag != null
        ? getIdForTag(tag)
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (notificationDetails.android?.ongoing == true && tag != null) {
      _ongoingTags.add(tag);
    }
    try {
      await _notifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: tag,
      );
    } catch (e) {
      print("Error showing notification: $e");
    }
  }

  static Future<void> cancelNotificationByTag(String tag) async {
    final id = _tagIds[tag];
    if (id != null) {
      await _notifications.cancel(id, tag: tag);
      _tagIds.remove(tag);
    }
    _ongoingTags.remove(tag);
  }

  // android

  static Future<AndroidNotificationDetails> _androidDetails(
    String? image,
    int? progressPercent,
    String? tag,
    bool silent,
    String? imageBody,
    List<AndroidNotificationsActionTypes>? actions,
  ) async {
    BigPictureStyleInformation? styleInfo;

    if (image != null && File(image).existsSync()) {
      styleInfo = BigPictureStyleInformation(FilePathAndroidBitmap(image),
          summaryText: imageBody);
    }

    return AndroidNotificationDetails(
      _channelId,
      _channelName,
      tag: tag,
      groupKey: 'yamata_launcher_group',
      channelDescription: _channelDescription,
      styleInformation: styleInfo,
      subText: image != null ? imageBody : null,
      importance: silent ? Importance.low : Importance.max,
      silent: silent,
      priority: silent ? Priority.low : Priority.high,
      autoCancel: progressPercent == null,
      playSound: progressPercent == null,
      ongoing: progressPercent != null,
      indeterminate: progressPercent == 0,
      maxProgress: 100,
      progress: progressPercent ?? 0,
      actions: actions
              ?.map((e) => androidNotificationActions[e]!)
              .toList(growable: false) ??
          [],
      showProgress: progressPercent != null,
    );
  }

  // mac & ios

  static DarwinNotificationDetails _darwinDetails(String? image) {
    if (image != null && File(image).existsSync()) {
      return DarwinNotificationDetails(
        attachments: [DarwinNotificationAttachment(image)],
      );
    }

    return const DarwinNotificationDetails();
  }

  // linux

  static LinuxNotificationDetails _linuxDetails(String? image) {
    return LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );
  }
}
