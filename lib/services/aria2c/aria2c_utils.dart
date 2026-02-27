import 'package:yamata_launcher/models/aria2c.dart';

class Aria2cUtils {
  static List<String> extractHeadersFromUrl(String url) {
    if (!url.contains("||")) return const [];
    final fragment = url.split("||")[1];
    if (!fragment.contains("headers:")) return const [];
    final raw = fragment.split("headers:")[1];
    return raw
        .split("^")
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toList();
  }

  /**
   * Cleans the URL by removing any appended parameters after "||".
   */
  static String getCleanUrl(String url) {
    if (!url.contains("||")) return url;
    return url.split("||").first;
  }

  static Aria2Progress parseProgress(String line) {
    print("aria2c: $line");
    return Aria2Progress(
      rawLine: line,
      percent: RegExp(r'\((\d+%)\)').firstMatch(line)?.group(1),
      downloaded: RegExp(r'\[#\w+\s+([^\s/]+)').firstMatch(line)?.group(1),
      total: RegExp(r'/([^\s(]+)\(').firstMatch(line)?.group(1),
      dlSpeed: RegExp(r'\bDL:([^\s]+)').firstMatch(line)?.group(1),
      ulSpeed: RegExp(r'\bUL:([^\s]+)').firstMatch(line)?.group(1),
      seeds: RegExp(r'\bSD:(\d+)').firstMatch(line)?.group(1),
      eta: RegExp(r'\bETA:([^\s]+)').firstMatch(line)?.group(1),
    );
  }

  static String formatProgress(Aria2Progress p) {
    final parts = <String>[];

    if (p.downloaded != null && p.total != null) {
      parts.add('${p.downloaded} / ${p.total}');
    }

    if (p.dlSpeed != null) {
      parts.add('↓ ${p.dlSpeed}');
    }

    if (p.ulSpeed != null) {
      parts.add('↑ ${p.ulSpeed}');
    }

    if (p.seeds != null) {
      parts.add('Seeds ${p.seeds}');
    }

    if (p.eta != null) {
      parts.add('ETA ${p.eta}');
    }

    if (p.dlSpeed != null &&
        [p.ulSpeed, p.seeds, p.eta].every((e) => e == null)) {
      return 'Fetching metadata...';
    }

    return parts.join(' • ').replaceAll("[", "").replaceAll("]", "");
  }
}
