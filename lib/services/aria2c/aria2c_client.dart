import 'dart:convert';
import 'dart:io';

import 'package:yamata_launcher/constants/torrents_constants.dart';
import 'package:yamata_launcher/models/aria2c.dart';
import 'package:yamata_launcher/services/aria2c/aria2c_utils.dart';
import 'package:yamata_launcher/services/scrapers/hosters/utils/common.dart';
import 'package:yamata_launcher/utils/process_helper.dart';
import 'package:path/path.dart' as p;
import 'package:yamata_launcher/utils/string_helper.dart';

enum DownloadUriType { magnet, torrent, direct }

class Aria2cClient {
  static DownloadUriType detectUriType(String uri) {
    if (uri.contains('magnet:')) return DownloadUriType.magnet;
    if (uri.toLowerCase().endsWith('.torrent')) return DownloadUriType.torrent;
    return DownloadUriType.direct;
  }

  static List<String> getCommonArgs(String? certPath, {String? downloadUrl}) {
    List<String> dhtSources = Platform.isAndroid
        ? [
            '--dht-entry-point=router.bittorrent.com:6881',
            '--dht-entry-point=dht.transmissionbt.com:6881',
            '--dht-entry-point=router.utorrent.com:6881',
          ]
        : [];

    List<String> params = [
      '--bt-tracker="${BT_TRACKERS.join(',')}"',
      "--auto-file-renaming=false",
      "--allow-overwrite=true",
      "--summary-interval=3",
      "--console-log-level=info",
      "--max-connection-per-server=1",
      '--header=User-Agent: ${CommonHosterUtils().hosterUserAgent}',
    ];
    if (downloadUrl != null && downloadUrl.contains("||")) {
      var headers = Aria2cUtils.extractHeadersFromUrl(downloadUrl);
      if (headers != null) {
        for (final header in headers) {
          params.add('--header=$header');
        }
      }
    }
    if (certPath != null) {
      params.add("--ca-certificate=${certPath}");
      var dhtPath = "${p.dirname(certPath!)}/dht.dat";
      if (Platform.isAndroid) {
        var dhtFile = File(dhtPath);
        if (!dhtFile.existsSync()) {
          dhtFile.createSync();
        }
        params.add("--bt-require-crypto=true");
        params.add("--disable-ipv6=true");
        params.add("--dht-file-path=${dhtPath}");
        params.add("--dht-file-path6=${p.dirname(certPath!)}/dht6.dat");
        params.addAll(dhtSources);
        params.addAll(
            ["--async-dns=true", "--async-dns-server=1.1.1.1,8.8.8.8,8.8.4.4"]);
      }
    }
    return params;
  }

  static Future<String> handleRedirects(String url) async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.isRedirect &&
        response.headers.value(HttpHeaders.locationHeader) != null) {
      final redirectedUrl = response.headers.value(HttpHeaders.locationHeader)!;
      return handleRedirects(redirectedUrl);
    } else {
      return url;
    }
  }

  static Future<Map<int, String>> showTorrentFiles({
    required String aria2cPath,
    required String torrentPath,
    String? certPath,
    String? cwd,
    void Function(String)? onLog,
    required void Function(Process) onSetRunning,
    required bool Function() isAborted,
  }) async {
    var commonArgs = getCommonArgs(certPath);
    final proc = await Process.start(
      aria2cPath,
      ['--show-files', torrentPath, ...commonArgs],
      workingDirectory: cwd,
    );

    onSetRunning(proc);

    final buffer = StringBuffer();
    proc.stdout.transform(utf8.decoder).listen(buffer.write);
    proc.stderr.transform(utf8.decoder).listen(buffer.write);

    await ProcessHelper.ensureExitOk(proc, isAborted, '--show-files failed');

    final reg = RegExp(r'^\s*(\d+)\|\s*(.+)$', multiLine: true);
    final matches = reg.allMatches(buffer.toString());

    if (matches.isEmpty) {
      throw StateError('No files found in torrent');
    }

    return {
      for (final m in matches) int.parse(m.group(1)!): m.group(2)!.trim()
    };
  }

  static Future<void> downloadSelectedFileFromTorrent({
    required String aria2cPath,
    required String torrentPath,
    int? selectIndex,
    String? cwd,
    String? certPath,
    void Function(String)? onLog,
    void Function(String)? onProgressLine,
    required void Function(Process) onSetRunning,
    required bool Function() isAborted,
  }) async {
    var certArgs = getCommonArgs(certPath);
    final proc = await Process.start(
      aria2cPath,
      [
        ...(selectIndex == null
            ? []
            : [
                '--select-file=$selectIndex',
                '--bt-remove-unselected-file=true'
              ]),
        '--seed-time=0',
        '--file-allocation=none',
        ...certArgs,
        torrentPath,
      ],
      workingDirectory: cwd,
    );

    onSetRunning(proc);
    ProcessHelper.pipeProcessOutput(
      process: proc,
      onLog: onLog,
      onProgress: onProgressLine,
    );

    await ProcessHelper.ensureExitOk(proc, isAborted, 'Download failed');
  }

  static Future<String> downloadTorrent({
    String? aria2cPath,
    required String uri,
    String? torrentsPath,
    String? certPath,
    void Function(String)? onLog,
    void Function(String)? onProgress,
    void Function(Process)? onRunning,
    bool Function()? isAborted,
  }) async {
    var uriHash = StringHelper.hash20(uri);
    final cache = Directory((torrentsPath ?? "") + "/${uriHash}")
      ..createSync(recursive: true);

    // CASE 1: Remote or local .torrent → download to cache
    if (uri.toLowerCase().endsWith('.torrent')) {
      final targetPath =
          p.join(cache.path, StringHelper.hash20(uri), p.basename(uri));

      // Skip download if already cached
      if (await File(targetPath).exists()) {
        return targetPath;
      }

      onLog!('Downloading torrent via HTTP: $uri');

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(uri));
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw StateError(
          'Failed to download torrent (HTTP ${response.statusCode})',
        );
      }

      final file = File(targetPath);
      final sink = file.openWrite();

      try {
        await for (final chunk in response) {
          if (isAborted!()) {
            await sink.close();
            try {
              await file.delete();
            } catch (e) {}

            throw StateError('Aborted');
          }
          sink.add(chunk);
        }
      } finally {
        await sink.close();
        client.close();
      }

      onLog('Torrent saved to cache: $targetPath');
      return targetPath;
    }

    // CASE 2: Magnet → generate torrent
    if (!uri.contains('magnet:')) {
      throw StateError('Invalid torrent URI');
    }

    final path = p.join(cache.path, '${uriHash}.torrent');
    if (await File(path).exists()) return path;
    var commonArgs = Aria2cClient.getCommonArgs(certPath, downloadUrl: uri);
    final proc = await Process.start(
      aria2cPath!,
      [
        '--bt-metadata-only=true',
        '--bt-save-metadata=true',
        '--seed-time=0',
        ...commonArgs,
        Aria2cUtils.getCleanUrl(uri),
      ],
      workingDirectory: cache.path,
    );

    onRunning!(proc);
    ProcessHelper.pipeProcessOutput(
      process: proc,
      onLog: onLog,
      onProgress: onProgress,
    );

    await ProcessHelper.ensureExitOk(
        proc, isAborted!, 'Metadata download failed');

    final torrent = cache
        .listSync()
        .whereType<File>()
        .where((f) => f
            .statSync()
            .modified
            .isAfter(DateTime.now().subtract(Duration(minutes: 2))))
        .firstWhere((f) => f.path.endsWith('.torrent'));

    await torrent.rename(path);
    return path;
  }
}
