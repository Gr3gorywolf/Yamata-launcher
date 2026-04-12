class TorrentHelper {
  static bool isMagnetUri(String value) {
    return value.trimLeft().startsWith("magnet:");
  }

  static String extractInfoHash(String magnetUri) {
    final uri = Uri.tryParse(magnetUri);
    if (uri == null || !uri.scheme.startsWith("magnet")) {
      throw Exception("Invalid magnet URI.");
    }

    final xtValues = uri.queryParametersAll["xt"] ?? const [];
    final btihValue = xtValues.cast<String?>().firstWhere(
          (value) =>
              value != null && value.toLowerCase().startsWith("urn:btih:"),
          orElse: () => null,
        );

    if (btihValue == null) {
      throw Exception("The magnet URI does not contain a BTIH hash.");
    }

    final rawHash = btihValue.substring("urn:btih:".length).trim();

    if (RegExp(r"^[a-fA-F0-9]{40}$").hasMatch(rawHash)) {
      return rawHash.toLowerCase();
    }

    if (RegExp(r"^[A-Z2-7]{32}$", caseSensitive: false).hasMatch(rawHash)) {
      return _bytesToHex(_decodeBase32(rawHash.toUpperCase()));
    }

    throw Exception("Unsupported magnet hash format.");
  }

  static List<int> _decodeBase32(String input) {
    const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    var buffer = 0;
    var bitsLeft = 0;
    final output = <int>[];

    for (final char in input.split("")) {
      final value = alphabet.indexOf(char);
      if (value < 0) {
        throw Exception("Invalid base32 character in magnet hash.");
      }

      buffer = (buffer << 5) | value;
      bitsLeft += 5;

      while (bitsLeft >= 8) {
        bitsLeft -= 8;
        output.add((buffer >> bitsLeft) & 0xff);
      }
    }

    return output;
  }

  static String _bytesToHex(List<int> bytes) {
    final output = StringBuffer();

    for (final byte in bytes) {
      output.write(byte.toRadixString(16).padLeft(2, '0'));
    }

    return output.toString();
  }
}
