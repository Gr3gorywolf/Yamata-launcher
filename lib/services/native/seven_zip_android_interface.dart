import 'dart:async';

import 'package:flutter/services.dart';

class SevenZipAndroidInterface {
  static const _channel = MethodChannel('yamata.launcher/methods');

  static final Map<String, Completer<void>> _tasks = {};

  static Future<bool> cancelExtract(String taskId) async {
    final result = await _channel.invokeMethod("cancelExtract", {
      "taskId": taskId,
    });
    return result as bool;
  }

  static Future<String> extract(
      String input, String output, Function(double) onProgress,
      {String? taskIdentifier, List<String> passwords = const []}) async {
    final taskId =
        taskIdentifier ?? DateTime.now().millisecondsSinceEpoch.toString();

    final completer = Completer<void>();
    _tasks[taskId] = completer;
    print("Starting extraction task with ID: $taskId");
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments as Map?;
      print("Received method call: ${call.method} with args: $args");
      if (args == null) return;

      final isTask = args["taskId"] == taskId;
      if (!isTask) return;

      switch (call.method) {
        case "extractProgress":
          final progress = (args["progress"] as num).toDouble();
          onProgress(progress);
          break;

        case "extractCompleted":
          if (!completer.isCompleted) completer.complete();
          break;

        case "extractError":
          if (!completer.isCompleted) {
            print("Extraction error for task $taskId: ${args["message"]}");
            completer.completeError(
              Exception(args["message"] ?? "Unknown extract error"),
            );
          }
          break;
      }
    });
    await _channel.invokeMethod("extractArchive", {
      "inputPath": input,
      "outputPath": output,
      "taskId": taskId,
      "passwords": passwords
    });

    return taskId;
  }

  static Future<void> wait(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    return task.future;
  }
}
