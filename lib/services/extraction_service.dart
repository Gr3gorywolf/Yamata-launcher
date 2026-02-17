import 'dart:async';
import 'dart:isolate';
import 'dart:io';

import 'package:provider/provider.dart';
import 'package:yamata_launcher/app_router.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/providers/download_sources_provider.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/native/seven_zip_android_interface.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/services/seven-zip/seven_zip_console_handler.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';

/// Represents special extraction progress states.
enum ExtractionSignal {
  unknown(-1),
  error(-2),
  complete(100);

  final double value;
  const ExtractionSignal(this.value);
}

class ExtractionService {
  static int maxConcurrent = 0;

  static final List<_QueueItem> _queue = <_QueueItem>[];
  static final Map<String, SendPort> _controlPorts = <String, SendPort>{};
  static int _running = 0;

  ExtractionService();

  static getZipPasswords() {
    final passwords = <String>{};
    passwords.addAll(COMMON_ZIP_PASSWORDS);
    final sourcesPasswords =
        Provider.of<DownloadSourcesProvider>(navigatorContext!, listen: false)
            .downloadSourcesPasswords;
    passwords.addAll(sourcesPasswords);
    return passwords.toList();
  }

  /// Adds an extraction task to the queue.
  static Future<(String id, Stream<double> progress)> enqueueExtraction({
    required File input,
    required Directory output,
    String? extractionId,
    void Function(Object error)? onError,
  }) async {
    final id = extractionId ?? DateTime.now().microsecondsSinceEpoch.toString();

    if (maxConcurrent == 0) {
      maxConcurrent = await SettingsService()
          .get<int>(SettingsKeys.MAX_CONCURRENT_EXTRACTIONS);
    }

    final completer = Completer<void>();
    final progressController = StreamController<double>.broadcast();

    final item = _QueueItem(
      id: id,
      input: input,
      output: output,
      completer: completer,
      progressController: progressController,
      onError: onError,
    );

    _queue.add(item);
    _tryRunNext();

    // Emit "unknown progress" once the extraction starts.
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!progressController.isClosed) {
        progressController.add(ExtractionProgress.unknown);
      }
    });

    completer.future.whenComplete(() {
      if (!progressController.isClosed) {
        progressController.close();
      }
    });

    return (id, progressController.stream);
  }

  /// Runs a single extraction immediately (not queued).
  static Future<(Stream<double> progress, void Function() cancel)> extractOnce({
    required File input,
    required Directory output,
    void Function(Object error)? onError,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final progressController = StreamController<double>.broadcast();

    progressController.add(0.0);

    final receivePort = ReceivePort();
    final controlPort = ReceivePort();
    Isolate? isolate;

    controlPort.listen((message) {
      if (message is SendPort) {
        _controlPorts[id] = message;
      }
    });

    final params = _buildParams(
      id: id,
      input: input,
      output: output,
      events: receivePort.sendPort,
      control: controlPort.sendPort,
      passwords: getZipPasswords(),
    );

    if (Platform.isAndroid) {
      _extractAndroid(params);
    } else {
      isolate = await Isolate.spawn(_extract, params);
    }

    Future.microtask(() {
      _listenToExtractionEvents(
        id: id,
        receivePort: receivePort,
        progressController: progressController,
        onError: onError,
        isolate: isolate,
        closeProgressOnDone: true,
      );

      progressController.add(ExtractionProgress.unknown);
    });

    void cancel() async {
      final ctrl = _controlPorts[id];
      if (ctrl != null) {
        ctrl.send({"type": "cancel"});
      }

      if (Platform.isAndroid) {
        await SevenZipAndroidInterface.cancelExtract(id);
      }
    }

    return (progressController.stream, cancel);
  }

  /// Cancels a queued or running extraction.
  static Future<void> cancel(String id) async {
    if (Platform.isAndroid) {
      await SevenZipAndroidInterface.cancelExtract(id);
    }

    final idx = _queue.indexWhere((q) => q.id == id);
    if (idx != -1) {
      final job = _queue.removeAt(idx);

      if (!job.progressController.isClosed) {
        job.progressController.add(0);
        job.progressController.close();
      }

      if (!job.completer.isCompleted) {
        job.completer.complete();
      }

      job.onError?.call('Cancelled before start');
      _tryRunNext();
      return;
    }

    final ctrl = _controlPorts[id];
    if (ctrl != null) {
      ctrl.send({"type": "cancel"});
    }
  }

  // ---------------- Queue & concurrency ----------------

  static void _tryRunNext() {
    if (_running >= maxConcurrent) return;
    if (_queue.isEmpty) return;

    final job = _queue.removeAt(0);
    _running++;

    _runJob(job).whenComplete(() {
      _running--;
      _tryRunNext();
    });
  }

  static Future<void> _runJob(_QueueItem job) async {
    final receivePort = ReceivePort();
    final controlPort = ReceivePort();

    job.progressController.add(0.0);

    controlPort.listen((message) {
      if (message is SendPort) {
        _controlPorts[job.id] = message;
      }
    });

    final params = _buildParams(
      id: job.id,
      input: job.input,
      output: job.output,
      events: receivePort.sendPort,
      control: controlPort.sendPort,
      passwords: getZipPasswords(),
    );

    Isolate? isolate;
    if (Platform.isAndroid) {
      _extractAndroid(params);
    } else {
      isolate = await Isolate.spawn(_extract, params);
    }

    await _listenToExtractionEvents(
      id: job.id,
      receivePort: receivePort,
      progressController: job.progressController,
      onError: job.onError,
      isolate: isolate,
      completer: job.completer,
      closeProgressOnDone: false,
    );
  }

  // ---------------- Shared helpers ----------------

  static Map<String, Object> _buildParams({
    required String id,
    required File input,
    required Directory output,
    required SendPort events,
    required SendPort control,
    required List<String> passwords,
  }) {
    return {
      "events": events,
      "control": control,
      "id": id,
      "input": input.path,
      "output": output.path,
      "sevenZipBinary": FileSystemService.sevenZipPath,
      "passwords": passwords,
    };
  }

  static Future<void> _listenToExtractionEvents({
    required String id,
    required ReceivePort receivePort,
    required StreamController<double> progressController,
    Isolate? isolate,
    Completer<void>? completer,
    void Function(Object error)? onError,
    required bool closeProgressOnDone,
  }) async {
    await for (final message in receivePort) {
      // Failure
      if (ExtractionProgress.isError(message)) {
        isolate?.kill(priority: Isolate.immediate);
        receivePort.close();
        _controlPorts.remove(id);

        var error =
            message['message'] ?? "Extraction failed with unknown error";

        if (completer != null && !completer.isCompleted) {
          completer.completeError(error);
        }

        if (!progressController.isClosed) {
          progressController.addError(error);
          if (closeProgressOnDone) await progressController.close();
        }

        onError?.call(error);
        return;
      }

      progressController.add(message);

      // Completed
      if (ExtractionProgress.isComplete(message)) {
        isolate?.kill(priority: Isolate.immediate);
        receivePort.close();
        _controlPorts.remove(id);

        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }

        if (closeProgressOnDone && !progressController.isClosed) {
          await progressController.close();
        }

        return;
      }
    }
  }

  // ---------------- Platform specific ----------------

  static Future<void> _extractAndroid(Map data) async {
    final events = data["events"] as SendPort;
    final inputPath = data["input"] as String;
    final outputPath = data["output"] as String;
    final taskId = data["id"] as String;
    final passwords = data["passwords"] as List<String>;
    try {
      await SevenZipAndroidInterface.extract(
        inputPath,
        outputPath,
        (progress) {
          final progressInt = progress.floor();

          if (progressInt >= 100 || progressInt.isOdd) return;

          events.send(progressInt.toDouble());
        },
        passwords: passwords,
        taskIdentifier: taskId,
      );

      await SevenZipAndroidInterface.wait(taskId);
      await Future.delayed(const Duration(milliseconds: 500));
      events.send(ExtractionSignal.complete.value);
    } catch (e) {
      print("Extraction error: $e");
      events.send({
        "type": "error",
        "message": e.toString(),
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
  }

  static Future<void> _extract(Map data) async {
    final events = data["events"] as SendPort;
    final controlAnnounce = data["control"] as SendPort;
    final sevenZipBinary = data["sevenZipBinary"] as String;
    final inputPath = data["input"] as String;
    final outputPath = data["output"] as String;
    final passwords = data["passwords"] as List<String>;

    final controlReceiver = ReceivePort();
    Process? extractionProcess;

    controlAnnounce.send(controlReceiver.sendPort);

    controlReceiver.listen((msg) {
      if (msg is Map && msg["type"] == "cancel") {
        print("Cancellation requested");
        try {
          extractionProcess?.kill(ProcessSignal.sigkill);
        } catch (e) {
          print("Failed to close input stream: $e");
        }
      }
    });

    try {
      await SevenZipConsoleHandler().extractFile(
        sevenZipBinary,
        inputPath,
        outputPath,
        (progress) {
          final progressInt = progress.floor();
          if (progressInt >= 100 || progressInt.isOdd) return;
          events.send(progressInt.toDouble());
        },
        passwords: passwords,
        onStart: (Process proc) {
          extractionProcess = proc;
        },
      );

      await Future.delayed(const Duration(milliseconds: 500));
      events.send(ExtractionSignal.complete.value);
    } catch (e) {
      print("Extraction error: $e");
      events.send({
        "type": "error",
        "message": e.toString(),
      });
    }
  }
}

/// Helper utilities for working with progress values.
class ExtractionProgress {
  static bool isError(dynamic value) =>
      value == ExtractionSignal.error.value ||
      (value is Map && value['type'] == 'error');

  static bool isComplete(double value) =>
      value >= ExtractionSignal.complete.value;

  static double get unknown => ExtractionSignal.unknown.value;
}

class _QueueItem {
  final String id;
  final File input;
  final Directory output;
  final Completer<void> completer;
  final StreamController<double> progressController;
  final void Function(Object error)? onError;

  _QueueItem({
    required this.id,
    required this.input,
    required this.output,
    required this.completer,
    required this.progressController,
    this.onError,
  });
}
