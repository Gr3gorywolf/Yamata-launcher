import 'dart:io';

import 'package:yamata_launcher/utils/process_helper.dart';

class SevenZipConsoleHandler {
  int? parseProgress(String line) {
    final regex = RegExp(r'(\d+)\s*%');
    final match = regex.firstMatch(line);

    if (match != null) {
      return int.parse(match.group(1)!);
    }

    return null;
  }

  Future extractFile(String sevenZipBinary, String archivePath,
      String outputPath, Function(double) progressCallback,
      {Function(Process)? onStart}) async {
    final proc = await Process.start(
      sevenZipBinary,
      [
        'x',
        '-y',
        '-bsp1',
        archivePath,
      ],
      workingDirectory: outputPath,
    );

    ProcessHelper.pipeProcessOutput(
      process: proc,
      onLog: (line) {
        print(line);
      },
      onProgress: (line) {
        {
          print(line);
          final progressVal = parseProgress(line);
          print(progressVal);
          if (progressVal != null) {
            progressCallback(progressVal.toDouble());
          }
        }
      },
      progressPrefix: '%',
    );
    onStart?.call(proc);

    await ProcessHelper.ensureExitOk(proc, () => false, 'Extraction failed');
  }
}
