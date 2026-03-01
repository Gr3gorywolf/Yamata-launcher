import 'dart:async';
import 'dart:convert';
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

  Future<bool> _archiveNeedsPassword(
      String sevenZipBinary, String archivePath) async {
    final proc = await Process.start(
      sevenZipBinary,
      ['l', '-slt', '-bd', '-p-', archivePath],
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final stdoutSub = proc.stdout
        .transform(SystemEncoding().decoder)
        .listen(stdoutBuffer.write);

    final stderrSub = proc.stderr
        .transform(SystemEncoding().decoder)
        .listen(stderrBuffer.write);

    try {
      final exitCode = await proc.exitCode.timeout(const Duration(seconds: 8));
      await stdoutSub.cancel();
      await stderrSub.cancel();

      final combined =
          (stdoutBuffer.toString() + stderrBuffer.toString()).toLowerCase();

      if (combined.contains('can not open encrypted archive') ||
          combined.contains('wrong password') ||
          exitCode != 0) {
        return true;
      }

      return false;
    } on TimeoutException {
      proc.kill(ProcessSignal.sigkill);
      await stdoutSub.cancel();
      await stderrSub.cancel();
      return true;
    }
  }

  Future<bool> _testPassword(
      String sevenZipBinary, String archivePath, String password) async {
    final proc = await Process.start(
      sevenZipBinary,
      ['t', '-p$password', archivePath],
    );

    final exitCode = await proc.exitCode;
    return exitCode == 0;
  }

  Future extractFile(
    String sevenZipBinary,
    String archivePath,
    String outputPath,
    Function(double) progressCallback, {
    Function(Process)? onStart,
    List<String> passwords = const [],
  }) async {
    String? workingPassword;

    final needsPassword =
        await _archiveNeedsPassword(sevenZipBinary, archivePath);
    print('Archive needs password: $needsPassword');

    print('The archive path: $archivePath');
    if (needsPassword) {
      for (final pwd in passwords) {
        final ok = await _testPassword(sevenZipBinary, archivePath, pwd);
        print('Testing password "$pwd": $ok');
        if (ok) {
          workingPassword = pwd;
          break;
        }
      }

      if (workingPassword == null) {
        throw Exception('Archive requires password and none matched');
      }
    }

    final args = [
      'x',
      '-y',
      '-bsp1',
      if (workingPassword != null) '-p$workingPassword',
      archivePath,
    ];

    final proc = await Process.start(
      sevenZipBinary,
      args,
      workingDirectory: outputPath,
    );

    ProcessHelper.pipeProcessOutput(
      process: proc,
      onLog: (line) {
        print(line);
      },
      onProgress: (line) {
        final progressVal = parseProgress(line);
        if (progressVal != null) {
          progressCallback(progressVal.toDouble());
        }
      },
      progressPrefix: '%',
    );

    onStart?.call(proc);

    await ProcessHelper.ensureExitOk(proc, () => false, 'Extraction failed');
  }
}
