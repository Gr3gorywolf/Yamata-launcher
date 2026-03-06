import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/constants/torrents_constants.dart';
import 'package:yamata_launcher/database/app_database.dart';
import 'package:yamata_launcher/database/daos/custom_path_dao.dart';
import 'package:yamata_launcher/models/aria2c.dart';
import 'package:yamata_launcher/models/download_source_rom.dart';
import 'package:yamata_launcher/models/rom_info.dart';
import 'package:yamata_launcher/services/aria2c/aria2c_client.dart';
import 'package:yamata_launcher/services/aria2c/aria2c_utils.dart';
import 'package:yamata_launcher/services/native/aria2c_android_interface.dart';
import 'package:yamata_launcher/services/native/wakelock_android_interface.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';
import 'package:yamata_launcher/utils/process_helper.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:path/path.dart' as p;

import '../files_system_service.dart';

/// ============================================================================
/// Internal Classes
/// ============================================================================
class IsolateActiveJob {
  final String? id;
  final Isolate? isolate;
  final ReceivePort? receivePort;
  final StreamSubscription? sub;
  final StreamController<Aria2Event>? controller;
  SendPort? controlPort;

  IsolateActiveJob({
    this.id,
    this.isolate,
    this.receivePort,
    this.sub,
    this.controller,
  });
}

class IsolateArgs {
  final RomInfo? rom;
  final DownloadSourceRom? source;
  final SendPort? sendPort;
  final String? aria2cPath;
  final String? uri;
  final int? fileIndex;
  final String? filePath;
  final String? downloadPath;
  final String? torrentsPath;
  final String? certPath;

  IsolateArgs({
    this.rom,
    this.sendPort,
    this.source,
    this.aria2cPath,
    this.uri,
    this.fileIndex,
    this.filePath,
    this.torrentsPath,
    this.downloadPath,
    this.certPath,
  });
}

class Aria2cDownloadManager {
  static final Map<String, IsolateActiveJob> _jobs = {};

  /// Starts a ROM download using:
  /// - [RomInfo]   → metadata / folder name
  /// - [DownloadSourceRom] → torrent source & file index
  static Future<Aria2DownloadHandle> startDownload({
    required RomInfo rom,
    required DownloadSourceRom source,
    String? aria2cPath,
    String? selectedDownloadPath,
  }) async {
    final uri = source.uris!.first;
    final id = StringHelper.hash20(rom.name + rom.console);

    if (_jobs.containsKey(id)) {
      throw StateError('Download already running for id=$id');
    }
    var includeConsolePrefix =
        await SettingsService().get<bool>(SettingsKeys.PREFIX_CONSOLE_SLUG);
    final receivePort = ReceivePort();
    final controller = StreamController<Aria2Event>.broadcast();
    final doneCompleter = Completer<Aria2DoneEvent>();
    var sanitizedRomName = StringHelper.removeInvalidPathCharacters(rom.name);
    var romSubFolder = sanitizedRomName.isEmpty
        ? "ROM_${StringHelper.generateUUID()}"
        : sanitizedRomName;
    var downloadPath = p.join(FileSystemService.downloadsPath,
        includeConsolePrefix ? rom.console : "", romSubFolder);
    var customDownloadPath = await CustomPathDao(db!).get(rom.console);
    if (customDownloadPath != null &&
        customDownloadPath.folderPath.isNotEmpty) {
      downloadPath = p.join(customDownloadPath.folderPath, romSubFolder);
    }

    if (selectedDownloadPath != null) {
      downloadPath = selectedDownloadPath;
    }

    var downloadMarkFile = File(p.join(downloadPath, DOWNLOAD_MARK_FILENAME));
    if (!await Directory(downloadPath).exists()) {
      await Directory(downloadPath).create(recursive: true);
      await downloadMarkFile.writeAsString(rom.slug ?? '');
    } else {
      if (!downloadMarkFile.existsSync()) {
        downloadPath =
            downloadPath + "_${StringHelper.generateUUID().substring(0, 5)}";
        await Directory(downloadPath).create(recursive: true);
        downloadMarkFile = File(p.join(downloadPath, DOWNLOAD_MARK_FILENAME));
        await downloadMarkFile.writeAsString(rom.slug ?? '');
      }
    }

    final isolate = await Isolate.spawn<IsolateArgs>(
      _downloadIsolateMain,
      IsolateArgs(
        rom: rom,
        source: source,
        sendPort: receivePort.sendPort,
        aria2cPath: aria2cPath,
        uri: Uri.decodeComponent(uri),
        fileIndex: source.fileIndex,
        certPath: Aria2cAndroidInterface.certPath.isEmpty
            ? null
            : Aria2cAndroidInterface.certPath,
        filePath: source.filePath != null
            ? Uri.decodeComponent(source.filePath!)
            : null,
        torrentsPath: FileSystemService.torrentsCachePath,
        downloadPath: downloadPath,
      ),
      debugName: 'aria2c-$id',
    );

    SendPort? controlPort;
    final sub = receivePort.listen((msg) {
      if (msg is! Map) return;

      switch (msg['type']) {
        case 'controlPort':
          controlPort = msg['port'];
          _jobs[id]?.controlPort = controlPort;
          break;

        case 'log':
          controller.add(Aria2LogEvent(msg['line']));
          break;

        case 'progress':
          controller.add(
            Aria2ProgressEvent(Aria2cUtils.parseProgress(msg['line'])),
          );
          break;

        case 'error':
          controller.add(Aria2ErrorEvent(msg['message']));
          if (!doneCompleter.isCompleted) {
            doneCompleter.completeError(
              StateError(msg['message']),
            );
          }
          _cleanup(id);
          break;

        case 'done':
          final ev = Aria2DoneEvent(
            outputFilePath: msg['outputFilePath'],
            selectedIndex: msg['selectedIndex'],
            selectedTorrentPath: msg['selectedTorrentPath'],
          );
          controller.add(ev);
          if (!doneCompleter.isCompleted) {
            doneCompleter.complete(ev);
          }
          _cleanup(id);
          break;
      }
    });

    void abort({bool deleteFiles = true}) {
      final job = _jobs.remove(id);
      if (job == null) return;
      job.controlPort?.send({'cmd': 'abort'});
      job.receivePort!.close();
      job.sub!.cancel();
      job.controller!.close();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (deleteFiles) {
          try {
            final dir = Directory(downloadPath);
            if (dir.existsSync()) {
              dir.deleteSync(recursive: true);
            }
          } catch (e) {}
        }
        job.isolate!.kill(priority: Isolate.immediate);
      });
    }

    _jobs[id] = IsolateActiveJob(
      id: id,
      isolate: isolate,
      receivePort: receivePort,
      sub: sub,
      controller: controller,
    );

    return Aria2DownloadHandle(
      id: id,
      folder: downloadPath,
      events: controller.stream,
      done: doneCompleter.future,
      abort: abort,
    );
  }

  static void _cleanup(String id) {
    final job = _jobs.remove(id);
    if (job == null) return;

    job.receivePort!.close();
    job.sub!.cancel();
    job.controller!.close();
  }
}

Future<void> _downloadIsolateMain(IsolateArgs args) async {
  final main = args.sendPort!;
  final control = ReceivePort();
  main.send({'type': 'controlPort', 'port': control.sendPort});

  bool aborted = false;
  Process? running;

  control.listen((msg) {
    if (msg is Map && msg['cmd'] == 'abort') {
      aborted = true;
      running?.kill(ProcessSignal.sigterm);
    }
  });

  void log(String m) => main.send({'type': 'log', 'line': m});
  void progress(String l) => main.send({'type': 'progress', 'line': l});
  void fail(Object e) => main.send({'type': 'error', 'message': e.toString()});

  try {
    final uriType = Aria2cClient.detectUriType(args.uri!);
    final romDir = Directory(args.downloadPath!)..createSync(recursive: true);

    // Direct download Http/FTP ETC
    if (uriType == DownloadUriType.direct) {
      var certArgs =
          Aria2cClient.getCommonArgs(args.certPath, downloadUrl: args.uri);
      print('Starting direct download with aria2c with args: ${certArgs}');
      final proc = await Process.start(
        args.aria2cPath!,
        [
          "--file-allocation=none",
          ...certArgs,
          Aria2cUtils.getCleanUrl(args.uri!)
        ],
        workingDirectory: romDir.path,
      );

      print(Aria2cUtils.getCleanUrl(args.uri!));

      running = proc;
      ProcessHelper.pipeProcessOutput(
        process: proc,
        onLog: log,
        onProgress: progress,
      );

      await ProcessHelper.ensureExitOk(
          proc, () => aborted, 'Direct download failed');

      var fileName = p.basename(
          Aria2cUtils.getCleanUrl(args.source?.fileName ?? args.uri!));
      var validExtensions = [
        ...VALID_COMPRESSED_EXTENSIONS,
        ...VALID_EXECUTABLE_EXTENSIONS,
        ...VALID_ROM_EXTENSIONS
      ];
      var filePath = p.join(romDir.path, fileName);
      if (validExtensions.firstWhereOrNull(
                  (extension) => fileName.endsWith(extension)) ==
              null ||
          !File(filePath).existsSync()) {
        var foundFile = RomService.searchRomFile(romDir)?.path;
        if (foundFile != null) {
          fileName = p.basename(foundFile);
        }
      }
      final outputPath = p.join(romDir.path, fileName);

      main.send({
        'type': 'done',
        'outputFilePath': outputPath,
        'selectedIndex': null,
        'selectedTorrentPath': null,
      });
      return;
    }

    // Torrent / Magnet downloads
    final torrentPath = await Aria2cClient.downloadTorrent(
      aria2cPath: args.aria2cPath,
      uri: args.uri!,
      onLog: log,
      certPath: args.certPath,
      torrentsPath: args.torrentsPath,
      onProgress: progress,
      onRunning: (p) => running = p,
      isAborted: () => aborted,
    );
    final files = await Aria2cClient.showTorrentFiles(
      aria2cPath: args.aria2cPath!,
      torrentPath: torrentPath,
      certPath: args.certPath,
      cwd: args.torrentsPath,
      onLog: log,
      onSetRunning: (p) => running = p,
      isAborted: () => aborted,
    );
    var fileIndex = args.fileIndex;
    if (fileIndex == null && args.filePath != null) {
      fileIndex = files.entries
          .firstWhereOrNull(
            (e) => e.value == args.filePath,
          )
          ?.key;
    }
    final relPath = fileIndex != null ? files[args.fileIndex!] : null;

    await Aria2cClient.downloadSelectedFileFromTorrent(
      aria2cPath: args.aria2cPath!,
      torrentPath: torrentPath,
      certPath: args.certPath,
      selectIndex: fileIndex,
      cwd: args.downloadPath,
      onLog: log,
      onProgressLine: progress,
      onSetRunning: (p) => running = p,
      isAborted: () => aborted,
    );
    String? outputPath = args.downloadPath;
    var canDeleteDirectories = args.rom != null &&
        !PLATFORMS_WITH_DIRECTORY_TYPE_GAMES
            .contains(args.rom!.console.toLowerCase());
    if (relPath != null) {
      outputPath = p.join(romDir.path, p.basename(relPath));
      final src = File(p.join(args.downloadPath!, relPath));
      final dst = File(outputPath);
      await src.rename(dst.path);
    } else {
      var romOutputPath = Directory(outputPath!);
      if (canDeleteDirectories) {
        await FileSystemService.flattenDirectoryFiles(romOutputPath.path);
      }
      var outputFile = RomService.searchRomFile(romOutputPath);
      if (outputFile != null) {
        outputPath = outputFile.path;
      }
    }

    // Cleanup residual folders
    if (canDeleteDirectories) {
      await for (var entity in Directory(args.downloadPath!).list()) {
        try {
          if (entity is Directory) {
            var isFolderEmpty =
                entity.listSync(recursive: true).whereType<File>().isEmpty;
            if (isFolderEmpty) {
              await entity.delete(recursive: true);
            }
          }
        } catch (e) {
          print('Error deleting extra directories: $e');
        }
      }
    }

    main.send({
      'type': 'done',
      'outputFilePath': outputPath,
      'selectedIndex': args.fileIndex,
      'selectedTorrentPath': torrentPath,
    });
  } catch (e) {
    fail(e);
  } finally {
    running?.kill(ProcessSignal.sigkill);
    control.close();
  }
}
