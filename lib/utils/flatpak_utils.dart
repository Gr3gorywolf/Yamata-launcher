import 'dart:io';

class FlatpakUtils {
  static Set<String>? cachedFlatpakApps;
  static DateTime? _lastCacheTime;
  static const _cacheTTL = Duration(seconds: 10);

  static Future<Process> launchFlatpak(
    String executable,
    List<String> args,
  ) async {
    final appId = await resolveFlatpakAppId(executable);

    if (appId == null) {
      throw Exception('Not a valid Flatpak executable: $executable');
    }
    print('Launching Flatpak app: $appId with args: $args');
    var process = Process.start(
      'flatpak',
      ['run', appId, ...args],
      mode: ProcessStartMode.normal,
    );

    return process;
  }

  static Future<bool> isFlatpakExecutable(String executable) async {
    final exec = executable.trim();

    final hasPath = exec.contains('/') || exec.contains('\\');

    // -------------------------
    // CASE 1: Path
    // -------------------------
    if (hasPath) {
      final normalized = exec.replaceAll('\\', '/');

      if (_isFlatpakPath(normalized)) return true;

      // Resolve symlinks
      try {
        final file = File(exec);
        if (await file.exists()) {
          final real = await file.resolveSymbolicLinks();

          if (_isFlatpakPath(real)) {
            return true;
          }
        }
      } catch (_) {}

      return false;
    }

    // -------------------------
    // CASE 2: App ID
    // -------------------------
    if (!_looksLikeFlatpakId(exec)) return false;
    final installedApps = await getInstalledFlatpakAppIds();

    if (installedApps.contains(exec)) {
      return true;
    }

    return false;
  }

  static Future<String?> resolveFlatpakAppId(String executable) async {
    final exec = executable.trim();

    // Case: already an ID
    if (_looksLikeFlatpakId(exec)) {
      final exists = await isFlatpakExecutable(exec);
      return exists ? exec : null;
    }

    // Case: path → extract ID
    final normalized = exec.replaceAll('\\', '/');

    final match =
        RegExp(r'/app/([^/]+)|/flatpak/app/([^/]+)').firstMatch(normalized);

    if (match != null) {
      final appId = match.group(1) ?? match.group(2);
      return appId;
    }

    // Try resolving symlink and retry
    try {
      final file = File(exec);
      if (await file.exists()) {
        final real = await file.resolveSymbolicLinks();

        final matchReal =
            RegExp(r'/app/([^/]+)|/flatpak/app/([^/]+)').firstMatch(real);

        if (matchReal != null) {
          return matchReal.group(1) ?? matchReal.group(2);
        }
      }
    } catch (_) {}

    return null;
  }

  static Future<Set<String>> getInstalledFlatpakAppIds() async {
    // Use cache if still valid
    if (cachedFlatpakApps != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheTTL) {
      return cachedFlatpakApps!;
    }

    try {
      final result = await Process.run(
        'flatpak',
        ['list', '--app', '--columns=application'],
      );

      if (result.exitCode != 0) {
        return {};
      }

      final output = (result.stdout as String);

      final apps = output
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();

      cachedFlatpakApps = apps;
      _lastCacheTime = DateTime.now();

      return apps;
    } catch (_) {
      return {};
    }
  }

  // --------------------------------------------------
  // HELPERS
  // --------------------------------------------------

  static bool _isFlatpakPath(String path) {
    return path.contains('/var/lib/flatpak/') ||
        path.contains('/.local/share/flatpak/') ||
        path.contains('/app/');
  }

  static bool _looksLikeFlatpakId(String input) {
    return RegExp(r'^[a-z0-9]+(\.[a-z0-9]+)+$', caseSensitive: false)
        .hasMatch(input);
  }
}
