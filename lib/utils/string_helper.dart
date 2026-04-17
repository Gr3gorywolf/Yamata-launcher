import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

extension StringNormalize on String {
  String normalizeForSearch() {
    final lower = toLowerCase();

    final sb = StringBuffer();
    for (final unit in lower.codeUnits) {
      final mapped = StringHelper.unicodeMap[unit] ?? unit;

      final ch = String.fromCharCode(mapped);
      if (RegExp(r'[a-z0-9\s]').hasMatch(ch)) {
        sb.write(ch);
      } else {
        sb.write(' ');
      }
    }

    return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> tokensForSearch() {
    final normalized = normalizeForSearch();
    if (normalized.isEmpty) return const [];
    final tokens = normalized.split(' ')..removeWhere((t) => t.isEmpty);
    tokens.sort();
    return tokens;
  }
}

class StringHelper {
  static const Map<String, String> diacriticsMap = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  static final Map<int, int> unicodeMap = {
    // A
    'á'.codeUnitAt(0): 'a'.codeUnitAt(0),
    'à'.codeUnitAt(0): 'a'.codeUnitAt(0),
    'ä'.codeUnitAt(0): 'a'.codeUnitAt(0),
    'â'.codeUnitAt(0): 'a'.codeUnitAt(0),
    'ā'.codeUnitAt(0): 'a'.codeUnitAt(0),

    // E
    'é'.codeUnitAt(0): 'e'.codeUnitAt(0),
    'è'.codeUnitAt(0): 'e'.codeUnitAt(0),
    'ë'.codeUnitAt(0): 'e'.codeUnitAt(0),
    'ê'.codeUnitAt(0): 'e'.codeUnitAt(0),
    'ē'.codeUnitAt(0): 'e'.codeUnitAt(0),

    // I
    'í'.codeUnitAt(0): 'i'.codeUnitAt(0),
    'ì'.codeUnitAt(0): 'i'.codeUnitAt(0),
    'ï'.codeUnitAt(0): 'i'.codeUnitAt(0),
    'î'.codeUnitAt(0): 'i'.codeUnitAt(0),
    'ī'.codeUnitAt(0): 'i'.codeUnitAt(0),

    // O
    'ó'.codeUnitAt(0): 'o'.codeUnitAt(0),
    'ò'.codeUnitAt(0): 'o'.codeUnitAt(0),
    'ö'.codeUnitAt(0): 'o'.codeUnitAt(0),
    'ô'.codeUnitAt(0): 'o'.codeUnitAt(0),
    'ō'.codeUnitAt(0): 'o'.codeUnitAt(0),
    'Ō'.codeUnitAt(0): 'o'.codeUnitAt(0),

    // U
    'ú'.codeUnitAt(0): 'u'.codeUnitAt(0),
    'ù'.codeUnitAt(0): 'u'.codeUnitAt(0),
    'ü'.codeUnitAt(0): 'u'.codeUnitAt(0),
    'û'.codeUnitAt(0): 'u'.codeUnitAt(0),
    'ū'.codeUnitAt(0): 'u'.codeUnitAt(0),

    // Others
    'ñ'.codeUnitAt(0): 'n'.codeUnitAt(0),
    'ç'.codeUnitAt(0): 'c'.codeUnitAt(0),
  };

  static bool hasMinConsecutiveMatch(
    String a,
    String b, {
    int minLength = 3,
  }) {
    final lenA = a.length;
    final lenB = b.length;

    if (lenA < minLength || lenB < minLength) return false;

    final short = lenA <= lenB ? a : b;
    final long = lenA <= lenB ? b : a;

    final shortLen = short.length;
    final longLen = long.length;

    for (int i = 0; i <= shortLen - minLength; i++) {
      for (int j = 0; j <= longLen - minLength; j++) {
        int k = 0;

        while (k < minLength &&
            short.codeUnitAt(i + k) == long.codeUnitAt(j + k)) {
          k++;
        }

        if (k == minLength) return true;
      }
    }

    return false;
  }

  static String removeInvalidPathCharacters(String input) {
    final invalidChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
    return input.replaceAll(invalidChars, '_');
  }

  static String getTitleFromFile(String filePath) {
    final segments = filePath.split(RegExp(r'[\\/]+'));
    final fileName = segments.isNotEmpty ? segments.last : filePath;

    final dotIndex = fileName.lastIndexOf('.');
    final rawTitle =
        dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;

    // Remove anything between (), [], {}
    final cleaned = rawTitle
        .replaceAll(RegExp(r'\([^)]*\)'), '') // ( ... )
        .replaceAll(RegExp(r'\[[^\]]*\]'), '') // [ ... ]
        .replaceAll(RegExp(r'\{[^}]*\}'), '') // { ... }
        .replaceAll(RegExp(r'\s{2,}'), ' ') // collapse spaces
        .trim();

    return cleaned;
  }

  static String getDomainName(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return "";
    }
  }

  static String truncateWithEllipsis(String input, int maxLength) {
    if (input.length <= maxLength) {
      return input;
    } else {
      return input.substring(0, maxLength - 3) + '...';
    }
  }

  static String hash20(String input) =>
      sha1.convert(utf8.encode(input)).toString().substring(0, 20);

  static String generateUUID() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = DateTime.now().microsecondsSinceEpoch.remainder(1000000);
    return '${timestamp}_$randomPart';
  }

  static bool isVersionStringNewer(String current, String reference) {
    var currentVersion = current.split(".");
    var newVersion = reference.split(".");

    for (var i = 0; i < newVersion.length; i++) {
      if (i >= currentVersion.length) {
        return true;
      }
      var newVerPart = int.tryParse(newVersion[i]) ?? 0;
      var currVerPart = int.tryParse(currentVersion[i]) ?? 0;
      if (newVerPart > currVerPart) {
        return true;
      } else if (newVerPart < currVerPart) {
        return false;
      }
    }
    return false;
  }

  static String formatNumber(int number) {
    final us = NumberFormat.decimalPattern('en_US');
    return us.format(number);
  }
}
