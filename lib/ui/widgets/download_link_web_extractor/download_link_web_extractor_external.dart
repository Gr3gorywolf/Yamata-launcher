import 'dart:io';
import 'package:flutter/material.dart';
import 'package:yamata_launcher/constants/app_constants.dart';
import 'package:yamata_launcher/constants/files_constants.dart';
import 'package:yamata_launcher/repository/download_sources_repository.dart';
import 'package:yamata_launcher/services/extraction_service.dart';
import 'package:yamata_launcher/services/files_system_service.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';
import 'package:yamata_launcher/utils/file_download_fetch.dart';
import 'package:yamata_launcher/utils/process_helper.dart';
import 'package:yamata_launcher/utils/url_helper.dart';

class DownloadLinkWebExtractorExternal extends StatefulWidget {
  String rawLink;
  DownloadLinkWebExtractorExternal({super.key, required this.rawLink});

  @override
  State<DownloadLinkWebExtractorExternal> createState() =>
      _DownloadLinkWebExtractorExternalState();
}

class _DownloadLinkWebExtractorExternalState
    extends State<DownloadLinkWebExtractorExternal> {
  bool isInstalled = false;
  bool isInstalling = false;
  int installProgressPercent = 0;
  String installProgressDescription = "";
  Function? cancelExtraction;
  Process? runningProcess;
  String? cookies;
  var isFulfilled = false;

  var markPath =
      p.join(FileSystemService.linkExtractorPath, DOWNLOAD_MARK_FILENAME);

  handleInit() async {
    setState(() {
      isInstalled = File(markPath).existsSync();
    });
    if (isInstalled) {
      handleRun();
    }
  }

  handleExtract(String filePath) async {
    setState(() {
      installProgressDescription = "Extracting files...";
    });
    var (stream, cancelFn) = await ExtractionService.extractOnce(
        input: File(filePath),
        output: Directory(FileSystemService.linkExtractorPath));
    var downloadMark = File(markPath);

    cancelExtraction = cancelFn;
    stream.listen((event) {
      if (event < 0) {
        setState(() {
          installProgressDescription = "Preparing extraction…";
        });
        return;
      }
      setState(() {
        installProgressPercent = event.toInt();
        installProgressDescription =
            "Unzipping… ${installProgressPercent.toStringAsFixed(2)}%";
      });
      if (installProgressPercent >= 100) {
        setState(() {
          installProgressDescription = "Finalizing installation...";
        });
        if (!downloadMark.existsSync()) {
          downloadMark.createSync();
        }
        try {
          File(filePath).deleteSync();
        } catch (e) {
          print("Error deleting temporary file: $e");
        }

        setState(() {
          isInstalling = false;
          isInstalled = true;
        });

        handleRun();
      }
    });
  }

  handleDownload() async {
    setState(() {
      isInstalling = true;
      installProgressPercent = 0;
      installProgressDescription = "Downloading external extractor tool...";
    });
    var linkExtractorDir = Directory(FileSystemService.linkExtractorPath);
    if (!linkExtractorDir.existsSync()) {
      linkExtractorDir.createSync(recursive: true);
    }
    var savePath = p.join(FileSystemService.linkExtractorPath, "extractor.zip");
    var res = await FileDownloadFetch(
        url: Uri.parse(AppConstants.externalLinkExtractorLink),
        savePath: savePath,
        onProgress: (progress) {
          setState(() {
            installProgressPercent = progress;
            installProgressDescription = "Downloading ... (${progress}%)";
          });

          if (progress == 100) {
            handleExtract(savePath);
          }
        });
    await res.start();
  }

  handleFullfill(String url) async {
    if (!mounted) return;
    if (isFulfilled) return;
    isFulfilled = true;
    Map<String, String> headers = {
      "User-Agent": CommonHosterUtils().hosterUserAgent,
      "Referer": widget.rawLink,
    };
    var fullUrl = UrlHelper.appendHeadersToUrl(url, headers);
    if (cookies != null && cookies?.isNotEmpty == true) {
      headers["Cookie"] = cookies!;
      fullUrl = UrlHelper.appendHeadersToUrl(fullUrl, headers);
    }
    Navigator.of(context).pop(url);
    await ProcessHelper.killProcessTree(runningProcess!);
    runningProcess = null;
  }

  handleRun() async {
    var hoster = DownloadSourcesRepository().getHosterForUrl(widget.rawLink);
    if (hoster == null) {
      print("No hoster found for url: ${widget.rawLink}");
      Navigator.of(context).pop();
      return;
    }

    var extractorPath = p.join(
        FileSystemService.linkExtractorPath,
        "yamata-link-extractor-${Platform.isWindows ? "windows" : Platform.isLinux ? "linux" : "macos"}");
    var extractionBinary = p.join(
        extractorPath, Platform.isWindows ? "extractor.bat" : "extractor.sh");

    if (!Platform.isWindows) {
      await Process.run("chmod", ["+x", extractionBinary]);
      await Process.run("chmod", ["+x", p.join(extractorPath, "node", "node")]);
      await Process.run("chmod", ["-R", "+x", p.join(extractorPath, "chrome")]);
    }
    final args = [widget.rawLink, "no-link-output"];

    runningProcess = await Process.start(
      extractionBinary,
      args,
      workingDirectory: extractorPath,
      runInShell: false,
      mode: ProcessStartMode.normal,
    );

    ProcessHelper.pipeProcessOutput(
      process: runningProcess!,
      onLog: (line) {
        print(line);
        if (line.startsWith("[cookies]")) {
          var cookiesString = line.replaceFirst("[cookies]", "").trim();
          cookies = cookiesString;
        }
        if (line.startsWith("[captured-url]")) {
          var url = line.replaceFirst("[captured-url]", "").trim();
          if (hoster.isValidDirectDownloadUrl(url)) {
            handleFullfill(url);
          }
        }
      },
      progressPrefix: '--',
    );
    try {
      await ProcessHelper.ensureExitOk(
          runningProcess!, () => false, 'Extraction failed');
      runningProcess = null;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {}
  }

  initState() {
    super.initState();
    handleInit();
  }

  @override
  void dispose() {
    if (cancelExtraction != null) {
      cancelExtraction!();
    }
    if (runningProcess != null) {
      ProcessHelper.killProcessTree(runningProcess!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Download link extraction"),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Builder(
            builder: (context) {
              if (isInstalled) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.watch_later, size: 48, color: Colors.green),
                    const Text("Waiting for the link extraction to complete…",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text(
                        "When the browser opens follow the hoster on-screen instructions until the download gets triggered, the download will start on the application as soon as the download link gets captured",
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    const CircularProgressIndicator(),
                  ],
                );
              }
              if (isInstalling) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.downloading, size: 48, color: Colors.green),
                    const Text("Installing external extractor tool…",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    CircularProgressIndicator(
                      value: installProgressPercent / 100,
                    ),
                    const SizedBox(height: 10),
                    Text(installProgressDescription,
                        textAlign: TextAlign.center)
                  ],
                );
              }
              if (!isInstalled) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        size: 48, color: Colors.orange),
                    const Text("External extractor not found",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text(
                        "You need to install the external link extractor tool, this is a full browser equiped with adblock capabilites made for this specific case. At least 1GB is needed to complete this installation.",
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: () async {
                          handleDownload();
                        },
                        child: const Text("Install & Run extractor"))
                  ],
                );
              }
              return Container();
            },
          ),
        ),
      ),
    );
  }
}
