import 'dart:io';

class FlatpakUtils {
  static Future<Process> launchFlatpak(
    String executable,
    List<String> args,
  ) async {
    final appId = await resolveFlatpakAppId(executable);

    if (appId == null) {
      throw Exception('Not a valid Flatpak executable: $executable');
    }

    return Process.start(
      'flatpak',
      ['run', appId, ...args],
      mode: ProcessStartMode.normal,
    );
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

    final home = Platform.environment['HOME'];

    final possiblePaths = [
      '/var/lib/flatpak/app/$exec',
      if (home != null) '$home/.local/share/flatpak/app/$exec',
    ];

    for (final path in possiblePaths) {
      if (await Directory(path).exists()) {
        return true;
      }
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
