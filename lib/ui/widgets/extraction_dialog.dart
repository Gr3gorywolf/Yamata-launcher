import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/services/extraction_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
import 'package:yamata_launcher/utils/string_helper.dart';
import 'package:yamata_launcher/utils/system_helpers.dart';

class ExtractionDialog extends StatefulWidget {
  final File zipFile;
  static Future<File?> show(BuildContext context, File zipFile) {
    return showDialog<File?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExtractionDialog(zipFile: zipFile),
    );
  }

  const ExtractionDialog({super.key, required this.zipFile});

  @override
  State<ExtractionDialog> createState() => _ExtractionDialogState();
}

class _ExtractionDialogState extends State<ExtractionDialog> {
  double progress = 0.0;
  String status = "Preparing…";
  Function? cancel;
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
      if (progress >= 100) {
        _handleComplete(tempFolder.path);
      }
    });
  }

  _handleComplete(String tempFolderPath) async {
    var dir = Directory(tempFolderPath);
    File? extractedFile =
        RomService.searchRomFile(dir, skipCompressedFiles: true);

    if (extractedFile != null) {
      var newFilePath =
          File(FileSystemService.moveFilesToParentFolder(extractedFile.path));
      if (newFilePath.existsSync()) {
        extractedFile = newFilePath;
        if (Platform.isAndroid && extractedFile != null) {
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
            isCanceling = true;
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
