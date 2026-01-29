import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

class FileDownloadFetch {
  final Uri url;
  final String savePath;
  final void Function(int progress) onProgress;
  final void Function()? onCancelled;

  http.Client? _client;
  StreamSubscription<List<int>>? _subscription;
  IOSink? _sink;
  bool _isCancelled = false;

  FileDownloadFetch({
    required this.url,
    required this.savePath,
    required this.onProgress,
    this.onCancelled,
  });

  Future<void> start() async {
    _client = http.Client();
    final request = http.Request('GET', url);
    final response = await _client!.send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to download file');
    }

    final totalBytes = response.contentLength ?? -1;
    int receivedBytes = 0;

    final file = File(savePath);
    _sink = file.openWrite();

    _subscription = response.stream.listen(
      (chunk) {
        if (_isCancelled) return;

        receivedBytes += chunk.length;
        _sink!.add(chunk);
        var recevedPercent =
            totalBytes > 0 ? ((receivedBytes / totalBytes) * 100).toInt() : 0;
        onProgress(recevedPercent);
      },
      onDone: () async {
        await _sink?.close();
        _client?.close();
      },
      onError: (e) async {
        await _sink?.close();
        _client?.close();
      },
      cancelOnError: true,
    );
  }

  Future<void> cancel({bool deletePartialFile = true}) async {
    _isCancelled = true;

    await _subscription?.cancel();
    await _sink?.close();
    _client?.close();

    if (deletePartialFile) {
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    onCancelled?.call();
  }
}
