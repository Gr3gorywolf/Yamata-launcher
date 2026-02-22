import 'dart:io';

enum LinuxVariant { steamOs, generic, batocera }

class OsService {
  static LinuxVariant? _linuxVariant;

  static LinuxVariant? get linuxVariant => _linuxVariant;
  static bool get isGenericLinuxVariant =>
      Platform.isLinux &&
      (linuxVariant == LinuxVariant.generic || linuxVariant == null);
  static init() async {
    if (Platform.isLinux) {
      try {
        var output =
            await Process.runSync("grep", ["PRETTY_NAME", "/etc/os-release"]);
        final prettyName = output.stdout.toString().toLowerCase();
        if (prettyName.contains("steamos") || prettyName.contains("bazzite")) {
          _linuxVariant = LinuxVariant.steamOs;
        } else if (prettyName.contains("batocera")) {
          _linuxVariant = LinuxVariant.batocera;
        } else {
          _linuxVariant = LinuxVariant.generic;
        }
      } catch (e) {
        _linuxVariant = LinuxVariant.generic;
        return;
      }
    }
  }
}
