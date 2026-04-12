import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:yamata_launcher/models/download_source.dart';

Future<String> buildWebManagerHtml() async {
  final data = {
    "downloadSourceTypes":
        DownloadSourceType.values.map((type) => type.name).toList(),
  };

  final html = await rootBundle.loadString('assets/web/web_manager.html');
  return html.replaceAll("{{data}}", jsonEncode(data));
}
