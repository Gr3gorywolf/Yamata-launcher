import 'dart:convert';
import 'dart:io';

class ProcessHelper {
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
