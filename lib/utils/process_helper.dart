import 'dart:convert';
import 'dart:io';

class ProcessHelper {
  static Future<void> killProcessTree(Process process) async {
    if (Platform.isWindows) {
      await Process.run('taskkill', [
        '/PID',
        process.pid.toString(),
        '/T',
        '/F',
      ]);
    } else {
      await Process.run('pkill', [
        '-TERM',
        '-P',
        process.pid.toString(),
      ]);
      process.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(milliseconds: 300));
      process.kill(ProcessSignal.sigkill);
    }
  }

  static Stream<String> _safeLines(Stream<List<int>> stream) {
    return stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty);
  }

  static void pipeProcessOutput({
    required Process process,
    void Function(String)? onLog,
    void Function(String)? onProgress,
    String? progressPrefix = '[#',
  }) {
    void handle(String line) {
      try {
        if (onProgress != null && line.contains(progressPrefix!)) {
          onProgress(line);
        }
        onLog!(line);
      } catch (e) {
        print('Error processing line: $e');
      }
    }

    _safeLines(process.stdout).listen(handle);
    _safeLines(process.stderr).listen(handle);
  }

  static Future<void> ensureExitOk(
    Process process,
    bool Function() isAborted,
    String errorMessage,
  ) async {
    final exitCode = await process.exitCode;
    if (isAborted()) throw StateError('Aborted');
    if (exitCode != 0) {
      throw StateError('$errorMessage (exitCode=$exitCode)');
    }
  }
}
