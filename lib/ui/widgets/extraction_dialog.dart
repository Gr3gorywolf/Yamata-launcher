import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/services/extraction_service.dart';
import 'package:yamata_launcher/services/rom_service.dart';
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
    var (stream, cancelFn) = await ExtractionService.extractOnce(
        input: widget.zipFile,
        output: widget.zipFile.parent,
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
        _handleComplete();
      }
    });
  }

  _handleComplete() async {
    var dir = widget.zipFile.parent;
    File? extractedFile =
        RomService.searchRomFile(dir, skipCompressedFiles: true);
    if (extractedFile != null) {
      if (Platform.isAndroid) {
        MediaScanner.loadMedia(path: extractedFile.path);
        MediaScanner.loadMedia(path: extractedFile.parent.path);
      }
      try {
        await widget.zipFile.delete();
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
