import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/providers/download_provider.dart';
import 'package:yamata_launcher/services/extraction_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/native/wakelock_android_interface.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';

class ExtractionDialog extends StatefulWidget {
  final File zipFile;
  final Function(String)? onError;
  static Future<File?> show(BuildContext context, File zipFile,
      {Function(String)? onError, bool moveToParentFolder = false}) {
    return showDialog<File?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExtractionDialog(zipFile: zipFile, onError: onError),
    );
  }

  ExtractionDialog({super.key, required this.zipFile, this.onError});

  @override
  State<ExtractionDialog> createState() => _ExtractionDialogState();
}

class _ExtractionDialogState extends State<ExtractionDialog> {
  double progress = 0.0;
  String status = "Preparing…";
  Function? cancel;
  var _tempDir = null;
  bool isCanceling = false;

  @override
  void initState() {
    super.initState();
    if (mounted) {
      _unzip();
    }
  }

  void _cancelWakeLock() {
    if (Platform.isAndroid) {
      var downloadProvider =
          Provider.of<DownloadProvider>(context, listen: false);
      if (downloadProvider.activeDownloadInfos.isEmpty) {
        WakelockAndroidInterface.setWakeLock(false);
      } else {
        print("Active downloads detected, keeping wakelock");
      }
    }
  }

  Future<void> _unzip() async {
    var tempFolder = Directory(
        p.join(widget.zipFile.parent.path, StringHelper.generateUUID()));
    if (Platform.isAndroid) {
      WakelockAndroidInterface.setWakeLock(true);
    }
    await tempFolder.create(recursive: true);
    var (stream, cancelFn) = await ExtractionService.extractOnce(
        input: widget.zipFile,
        output: tempFolder,
        onError: (data) {
          print("Extraction error: $data");
          Future.delayed(Duration(seconds: 1), () {
            _cleanupTempDir();
            widget?.onError?.call(data as String);
          }).then((_) {});
          _cancelWakeLock();

          if (!isCanceling) {
            Navigator.of(context).pop();
          }
        });
    cancel = cancelFn;
    stream.listen((event) {
      if (event < 0) {
        setState(() {
          status = "Preparing…";
        });
        return;
      }
      setState(() {
        progress = event.ceilToDouble();
        status = "Unzipping… ${progress.toStringAsFixed(2)}%";
      });
      _tempDir = tempFolder.path;
      if (progress >= 100) {
        _handleComplete(tempFolder.path);
      }
    });
  }

  _handleComplete(String tempFolderPath) async {
    try {
      var dir = Directory(tempFolderPath);
      File? extractedFile =
          RomService.searchRomFile(dir, skipCompressedFiles: true);

      if (extractedFile != null) {
        var movingResult = FileSystemService.moveFilesToParentFolder(
            tempFolderPath,
            filePath: extractedFile.path);
        var newFilePath = File(movingResult.filePath ?? "");
        if (newFilePath.existsSync() && movingResult.filePath != null) {
          extractedFile = newFilePath;
          if (Platform.isAndroid) {
            try {
              MediaScanner.loadMedia(path: extractedFile.path);
              MediaScanner.loadMedia(path: extractedFile.parent.path);
            } catch (e) {
              print("Error loading media: ${e.toString()}");
            }
          }
          try {
            await ExtractionService.deleteZipFiles(widget.zipFile.path);
          } catch (e) {}
        }
        try {
          dir.deleteSync(recursive: true);
        } catch (e) {}
      }
      _cancelWakeLock();
      Navigator.of(context).pop(extractedFile);
    } on Exception catch (e) {
      print("Extraction completition error: ${e.toString()}");
      Future.microtask(() {
        widget?.onError?.call(e.toString());
      }).then((_) {});
      _cancelWakeLock();
      Navigator.of(context).pop();
      return;
    }
  }

  _cleanupTempDir() {
    if (_tempDir != null) {
      try {
        Directory(_tempDir).deleteSync(recursive: true);
      } catch (e) {
        print(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Unzipping…"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress / 100),
          const SizedBox(height: 12),
          Text(status, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            isCanceling = true;
            cancel!();
            Future.delayed(Duration(seconds: 1), () {
              _cleanupTempDir();
              Navigator.of(context).pop();
            });
            setState(() {
              status = "Aborting...";
            });
          },
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
