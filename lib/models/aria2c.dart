/// Progress parsed from aria2c lines.
class Aria2Progress {
  final String? percent; // e.g. "98%"
  final String? downloaded; // e.g. "811MiB"
  final String? total; // e.g. "823MiB"
  final String? dlSpeed; // e.g. "37MiB"
  final String? ulSpeed; // e.g. "4.6MiB"
  final String? seeds; // SD:<n>
  final String? eta; // if present in output
  final String? rawLine;

  Aria2Progress({
    this.rawLine,
    this.percent,
    this.downloaded,
    this.total,
    this.dlSpeed,
    this.ulSpeed,
    this.seeds,
    this.eta,
  });

  @override
  String toString() {
    final parts = <String>[];
    if (percent != null) parts.add('pct=$percent');
    if (downloaded != null && total != null)
      parts.add('done=$downloaded/$total');
    if (dlSpeed != null) parts.add('dl=$dlSpeed');
    if (ulSpeed != null) parts.add('ul=$ulSpeed');
    if (seeds != null) parts.add('sd=$seeds');
    if (eta != null) parts.add('eta=$eta');
    return 'Aria2Progress(${parts.join(', ')})';
  }
}

/// Events emitted from the isolate.
class Aria2Event {
  const Aria2Event();
}

class Aria2ProgressEvent extends Aria2Event {
  final Aria2Progress progress;
  const Aria2ProgressEvent(this.progress);
}

class Aria2LogEvent extends Aria2Event {
  final String? line;
  const Aria2LogEvent(this.line);
}

class Aria2DoneEvent extends Aria2Event {
  final String? outputFilePath;
  final int? selectedIndex;
  final String? selectedTorrentPath;
  const Aria2DoneEvent({
    this.outputFilePath,
    this.selectedIndex,
    this.selectedTorrentPath,
  });
}

class Aria2ErrorEvent extends Aria2Event {
  final String? message;
  const Aria2ErrorEvent(this.message);
}

/// Handle returned to the caller to listen to events and abort.
class Aria2DownloadHandle {
  final String id;
  final String folder;
  final Stream<Aria2Event> events;
  final Future<Aria2DoneEvent> done;
  final void Function({bool deleteFiles}) abort;

  Aria2DownloadHandle({
    required this.id,
    required this.folder,
    required this.events,
    required this.done,
    required this.abort,
  });
}
