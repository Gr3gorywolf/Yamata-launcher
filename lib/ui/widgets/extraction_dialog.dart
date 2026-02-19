import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/constants/settings_constants.dart';
import 'package:yamata_launcher/services/extraction_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/services/settings_service.dart';
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

  Future<void> _unzip() async {
    var tempFolder = Directory(
        p.join(widget.zipFile.parent.path, StringHelper.generateUUID()));
    await tempFolder.create(recursive: true);
    var (stream, cancelFn) = await ExtractionService.extractOnce(
        input: widget.zipFile,
        output: tempFolder,
        onError: (data) {
          print("Extraction error: $data");
          Future.microtask(() {
            widget?.onError?.call(data as String);
          }).then((_) {});

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
            MediaScanner.loadMedia(path: extractedFile.path);
            MediaScanner.loadMedia(path: extractedFile.parent.path);
          }
          try {
            await widget.zipFile.delete();
          } catch (e) {}
        }
        try {
          dir.deleteSync(recursive: true);
        } catch (e) {}
      }
      Navigator.of(context).pop(extractedFile);
    } on Exception catch (e) {
      Future.microtask(() {
        widget?.onError?.call(e.toString());
      }).then((_) {});
      Navigator.of(context).pop();
      return;
    }
  }

  _cleanupTempDir() {
    if (_tempDir != null) {
      try {
        Directory(_tempDir).deleteSync(recursive: true);
      } catch (e) {}
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
          onPressed: () {
            cancel!();
            _cleanupTempDir();
            isCanceling = true;
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
