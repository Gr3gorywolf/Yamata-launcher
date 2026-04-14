import 'dart:async';
import 'package:another_flushbar/flushbar.dart';
import 'package:another_flushbar/flushbar_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/main.dart';
import 'package:yamata_launcher/models/update_info.dart';
import 'package:yamata_launcher/providers/app_provider.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/update_service.dart';
import 'package:yamata_launcher/ui/layouts/main_layout.dart';
import 'package:yamata_launcher/ui/widgets/loading_alert_dialog_content.dart';

class AlertsService {
  static Flushbar? _currentSnackbar;
  static bool isUpdateAlertOpen = false;
  static showSnackbar(String message,
      {String? title,
      IconData? icon,
      int duration = 2,
      BuildContext? ctx,
      FlushbarPosition? position = null,
      Function? onTap}) async {
    if (icon == null) {
      icon = Icons.info;
    }
    if (position == null) {
      position = FileSystemService.isDesktop
          ? FlushbarPosition.TOP
          : FlushbarPosition.BOTTOM;
    }
    _currentSnackbar = await Flushbar(
      margin: EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      duration: Duration(seconds: duration),
      title: title,
      flushbarPosition: position,
      maxWidth: 600,
      flushbarStyle: FlushbarStyle.FLOATING,
      message: message,
      backgroundColor: Theme.of(navigatorContext!).colorScheme.surface,
      titleColor: Theme.of(navigatorContext!).colorScheme.onSurface,
      messageColor:
          Theme.of(navigatorContext!).colorScheme.onSurface.withOpacity(0.8),
      onTap: (bar) {
        if (onTap != null) onTap();
      },
      shouldIconPulse: false,
      icon: Icon(
        icon,
        color: Theme.of(navigatorContext!).colorScheme.primary,
      ),
    ).show(ctx ?? navigatorContext!);
  }

  static showErrorSnackbar(String message,
      {FlushbarPosition? position = null,
      BuildContext? ctx,
      Exception? exception}) async {
    var exceptionText = "Wow, an unexpected error happened";
    if (exception != null) {
      exceptionText = exception.toString();
    }
    if (position == null) {
      position = FileSystemService.isDesktop
          ? FlushbarPosition.TOP
          : FlushbarPosition.BOTTOM;
    }
    _currentSnackbar = await Flushbar(
      margin: EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      duration: Duration(seconds: 4),
      title: exception == null ? null : message,
      backgroundColor: Theme.of(ctx ?? navigatorContext!).colorScheme.error,
      maxWidth: 600,
      flushbarStyle: FlushbarStyle.FLOATING,
      flushbarPosition: position,
      message: exception == null ? message : exceptionText,
      icon: Icon(
        Icons.error,
        color: Colors.white,
      ),
    ).show(ctx ?? navigatorContext!);
  }

  static Future<String?> showPrompt(BuildContext ctx, String title,
      {String? message,
      TextInputType inputType = TextInputType.text,
      String? inputPlaceholder,
      Widget? extraContent,
      String? initialValue,
      int lines = 1,
      double? minWidth = 300}) {
    var completer = Completer<String?>();
    var controller = TextEditingController(text: initialValue ?? "");
    showDialog(
        context: ctx,
        builder: (cont) {
          return AlertDialog(
            title: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            titlePadding: EdgeInsets.only(top: 20, left: 13, bottom: 5),
            content: Container(
              width: minWidth,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: controller,
                  keyboardType: inputType,
                  decoration: InputDecoration(
                    hintText: inputPlaceholder ?? "",
                    helperText: message ?? "",
                    helperMaxLines: 3,
                  ),
                  minLines: lines,
                  maxLines: lines,
                  onChanged: (text) {
                    controller.text = text;
                  },
                ),
                if (extraContent != null) ...[
                  SizedBox(height: 10),
                  extraContent,
                ],
              ]),
            ),
            actions: [
              TextButton(
                  style: TextButton.styleFrom(
                      textStyle: TextStyle(color: Colors.red)),
                  onPressed: () {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    completer.complete(null);
                  },
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    completer.complete(controller.text);
                  },
                  child: Text("Ok"))
            ],
          );
        });

    return completer.future;
  }

  static _DialogHandle showLoadingAlert(
    BuildContext ctx,
    String title,
    String text, {
    ValueNotifier<double?>? progressNotifier,
  }) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogContext) {
        Widget content;

        if (progressNotifier == null) {
          content = LoadingAlertDialogContent(text: text);
        } else {
          content = ValueListenableBuilder<double?>(
            valueListenable: progressNotifier,
            builder: (context, progress, _) {
              final displayText = progress == null
                  ? text
                  : '$text (${(progress * 100).toStringAsFixed(0)}%)';

              return LoadingAlertDialogContent(
                text: displayText,
                progress: progress,
              );
            },
          );
        }

        return AlertDialog(
          title: Text(
            title,
            style: Theme.of(ctx).textTheme.titleMedium,
          ),
          content: content,
        );
      },
    );

    final navigator = Navigator.of(ctx, rootNavigator: true);
    return _DialogHandle(() {
      if (navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  static Future<T?> showAlert<T>(BuildContext ctx, String title, String text,
      {Function? callback = null,
      Function? onClose = null,
      bool cancelable = true,
      Widget? extraContent = null,
      String acceptTitle = "Ok",
      Color? textColor = null,
      TextButton? additionalAction = null}) {
    return showDialog<T>(
        context: ctx,
        barrierDismissible: cancelable,
        builder: (cont) {
          return AlertDialog(
            actionsAlignment: MainAxisAlignment.end,
            title: Text(
              title,
              style: TextStyle(color: textColor ?? Colors.green),
            ),
            backgroundColor: Colors.grey[900],
            content: SingleChildScrollView(
              child: Container(
                  constraints: BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(text,
                          style: TextStyle(color: textColor ?? Colors.green)),
                      if (extraContent != null) ...[
                        SizedBox(height: 10),
                        extraContent,
                      ],
                    ],
                  )),
            ),
            actions: [
              if (cancelable || onClose != null)
                TextButton(
                    style: TextButton.styleFrom(
                        textStyle: TextStyle(color: Colors.red)),
                    onPressed: () {
                      Navigator.of(ctx, rootNavigator: true).pop();
                      if (onClose != null) {
                        onClose();
                      }
                    },
                    child: Text("Cancel")),
              SizedBox(
                width: 10,
              ),
              additionalAction ?? SizedBox(),
              TextButton(
                  onPressed: () {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    if (callback != null) {
                      callback();
                    }
                  },
                  child: Text(acceptTitle))
            ],
          );
        });
  }

  static Future<PickerOption?> showPicker(
      BuildContext context, String title, List<PickerOption> options) {
    return showAlert(context, title, "",
        extraContent: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map((option) => ListTile(
                      title: Text(option.label),
                      onTap: () {
                        Navigator.of(context).pop(option);
                      },
                    ))
                .toList(),
          ),
        ));
  }

  static void showUpdateChangelogAlert(
      BuildContext context, UpdateInfo update) {
    showDialog(
        context: context,
        builder: (cont) {
          return AlertDialog(
            title: Text("What's new on version ${update.version}?",
                style: Theme.of(context).textTheme.titleMedium),
            content: Container(
                constraints: BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(child: Text(update.changelog))),
            actions: [
              TextButton(
                  onPressed: () {
                    if (update.downloadedFilePath != null) {
                      UpdateService.handleInstall();
                    } else {
                      UpdateService.startUpdateDownload();
                      AlertsService.showUpdateAppBanner(
                          mainLayoutKey.currentContext!);
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                  },
                  child: Text(update?.downloadedFilePath != null
                      ? "Install"
                      : "Download")),
              TextButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                  child: Text("Close"))
            ],
          );
        });
  }

  static void showUpdateAppBanner(BuildContext context) {
    if (isUpdateAlertOpen == true) return;
    isUpdateAlertOpen = true;
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                isUpdateAlertOpen = false;
                if (UpdateService.currentDownload != null) {
                  UpdateService.cancelUpdateDownload();
                }
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
            ),
            const SizedBox(width: 8),
            const Icon(Icons.cloud_download_outlined),
          ],
        ),
        content: Consumer<AppProvider>(
          builder: (context, app, _) {
            final update = app.updateInfo;

            if (update == null) {
              return const Text('Checking for updates...');
            }

            if (!update.isDownloading) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(update.downloadedFilePath != null
                          ? 'Update ${update.version} is ready to install.'
                          : 'App version ${update.version} is available.'),
                      const SizedBox(height: 1),
                      TextButton(
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.all(2),
                              minimumSize: Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          onPressed: () {
                            AlertsService.showUpdateChangelogAlert(
                                context, update);
                          },
                          child: Text('View details'))
                    ]),
              );
            }

            final percent = update.progress ?? 0;
            final progress = percent / 100;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Downloading update ${update.version}... $percent%'),
                const SizedBox(height: 8),
                if (update.progress != null)
                  LinearProgressIndicator(value: progress)
                else
                  const LinearProgressIndicator(),
              ],
            );
          },
        ),
        actions: [
          Consumer<AppProvider>(
            builder: (context, app, _) {
              final update = app.updateInfo;
              if (update?.progress == 100 &&
                  update?.downloadedFilePath != null) {
                return TextButton(
                  onPressed: () {
                    UpdateService.handleInstall();
                  },
                  child: Text('Install'),
                );
              }

              return TextButton(
                onPressed: update?.isDownloading == true
                    ? UpdateService.cancelUpdateDownload
                    : UpdateService.startUpdateDownload,
                child: Text(
                  update?.isDownloading == true ? 'Cancel' : 'Download',
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DialogHandle {
  bool _closed = false;
  final VoidCallback _onClose;

  _DialogHandle(this._onClose);

  void close() {
    if (_closed) return;
    _onClose();
    _closed = true;
  }
}

class PickerOption {
  final String label;
  final dynamic value;

  PickerOption({required this.label, required this.value});
}
